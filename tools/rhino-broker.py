#!/usr/bin/env python3
"""Run a prefix's Wine commands in the Flatpak instance that runs its wineserver.

Every `flatpak run` starts a sandbox with its own PID namespace, while all of
them share /tmp, where Wine keeps the wineserver socket. A wineserver signals
its processes by their process ids, which mean nothing in another namespace, so
it refuses processes of other instances. The first launcher of a prefix starts
a broker next to it; later launchers, in other instances (a second Rhino, a
.3dm opened from the file manager, --stop), hand it their command line, and the
broker runs it in its own instance and passes its output and exit code back.

  rhino-broker.py run PREFIX -- CMD [ARG...]
      Run CMD in the broker's instance. Exits with CMD's exit code, or 3 when
      no broker runs for PREFIX.
  rhino-broker.py claim PREFIX
      Start the broker for PREFIX in this instance. Exits 0 once it listens,
      or 4 when another instance has one.
"""

import fcntl
import json
import os
import socket
import struct
import subprocess
import sys
import threading
import time

NO_BROKER = 3
OTHER_OWNER = 4
CHILD_ENV = "RHINO_BROKER_CHILD"


def prefix_id(prefix):
    st = os.stat(prefix)
    return "%x-%x" % (st.st_dev, st.st_ino)


def broker_dir():
    path = "/tmp/rhino-linux-%d" % os.getuid()
    os.makedirs(path, mode=0o700, exist_ok=True)
    return path


def paths(prefix):
    base = os.path.join(broker_dir(), "broker-" + prefix_id(prefix))
    return base + ".sock", base + ".lock"


def wineserver_running(prefix):
    """Whether a wineserver holds the lock of PREFIX's server directory."""
    lock = "/tmp/.wine-%d/server-%s/lock" % (os.getuid(), prefix_id(prefix))
    try:
        fd = os.open(lock, os.O_RDWR)
    except OSError:
        return False
    try:
        # F_GETLK only looks: taking the lock, even briefly, could make a starting
        # wineserver believe another one runs. struct flock on Linux x86_64.
        query = struct.pack("hhxxxxqqixxxx", fcntl.F_WRLCK, os.SEEK_SET, 0, 1, 0)
        l_type = struct.unpack("hhxxxxqqixxxx", fcntl.fcntl(fd, fcntl.F_GETLK, query))[0]
        return l_type != fcntl.F_UNLCK
    except OSError:
        return False
    finally:
        os.close(fd)


# Messages are a kind byte, a length and data: 'o'/'e' output, 'x' exit code.

def send_msg(sock, kind, data):
    sock.sendall(kind + struct.pack("!I", len(data)) + data)


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise EOFError
        data += chunk
    return data


def recv_msg(sock):
    head = recv_exact(sock, 5)
    return head[:1], recv_exact(sock, struct.unpack("!I", head[1:])[0])


def run(prefix, argv):
    sock_path, _ = paths(prefix)
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(sock_path)
    except OSError:
        return NO_BROKER
    request = {"argv": argv, "cwd": os.getcwd(), "env": dict(os.environ)}
    request["env"][CHILD_ENV] = "1"
    send_msg(sock, b"r", json.dumps(request).encode())
    out = {b"o": sys.stdout.buffer, b"e": sys.stderr.buffer}
    try:
        while True:
            kind, data = recv_msg(sock)
            if kind == b"x":
                return int(data)
            out[kind].write(data)
            out[kind].flush()
    except EOFError:
        return 1


def serve_client(conn, children):
    with conn:
        try:
            kind, data = recv_msg(conn)
            request = json.loads(data)
            proc = subprocess.Popen(request["argv"], cwd=request["cwd"], env=request["env"],
                                    stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, start_new_session=True)
        except Exception as e:
            try:
                send_msg(conn, b"e", ("rhino-broker: %s\n" % e).encode())
                send_msg(conn, b"x", b"1")
            except OSError:
                pass
            return
        children.add(proc)

        def relay(stream, kind):
            for chunk in iter(lambda: stream.read1(65536), b""):
                try:
                    send_msg(conn, kind, chunk)
                except OSError:
                    pass  # the caller went away; the command keeps running

        threads = [threading.Thread(target=relay, args=(proc.stdout, b"o"), daemon=True),
                   threading.Thread(target=relay, args=(proc.stderr, b"e"), daemon=True)]
        for t in threads:
            t.start()
        code = proc.wait()
        for t in threads:
            t.join()
        children.discard(proc)
        try:
            send_msg(conn, b"x", str(code).encode())
        except OSError:
            pass


def serve(prefix, server, lock_fd, ready_fd):
    children = set()
    os.write(ready_fd, b"1")
    os.close(ready_fd)
    started = time.monotonic()

    def watch():
        # Leave once the wineserver ended and nothing runs for a caller, so that
        # this Flatpak instance can end too; give the launcher time to start it.
        while True:
            time.sleep(2)
            if time.monotonic() - started < 30:
                continue
            if not children and not wineserver_running(prefix):
                sock_path, _ = paths(prefix)
                try:
                    os.unlink(sock_path)
                except OSError:
                    pass
                os._exit(0)

    threading.Thread(target=watch, daemon=True).start()
    while True:
        conn, _ = server.accept()
        threading.Thread(target=serve_client, args=(conn, children), daemon=True).start()


def claim(prefix):
    sock_path, lock_path = paths(prefix)
    lock_fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return OTHER_OWNER
    try:
        os.unlink(sock_path)  # left over by a broker that did not exit cleanly
    except OSError:
        pass
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(sock_path)
    server.listen(16)

    ready_r, ready_w = os.pipe()
    if os.fork():
        os.close(ready_w)
        ok = os.read(ready_r, 1) == b"1"
        return 0 if ok else 1
    # the broker: detach from the launcher, keep the lock and the socket
    os.close(ready_r)
    os.setsid()
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)
    serve(prefix, server, lock_fd, ready_w)


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "claim":
        return claim(sys.argv[2])
    if len(sys.argv) >= 5 and sys.argv[1] == "run" and sys.argv[3] == "--":
        return run(sys.argv[2], sys.argv[4:])
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
