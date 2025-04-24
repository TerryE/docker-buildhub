#!/usr/bin/env python3
"""
Container Supervisor (v2.0)
- Uses HOSTNAME for service context
- Minimal process management only
- Robust listener process restart
- Proper Docker logging passthrough
"""

import os
import sys
import signal
import subprocess
import socket
import threading
from pathlib import Path
import time

class ContainerSupervisor:
    def __init__(self):
        self.service = os.environ['HOSTNAME']
        self.listener = 'listener'
        self.entrypoint = 'entrypoint'
        self.processes = {}
        self.shutdown_requested = False
        self.setup_signal_handlers()
        self.socket_path = Path(f'/run/{self.service}-request.sock')
        self.setup_runtime_environment()

    def setup_runtime_environment(self):
        """Ensure runtime directories exist with correct permissions"""
        if self.socket_path.exists():
            self.socket_path.unlink()

    def setup_signal_handlers(self):
        """Capture and propagate signals to children"""
        signal.signal(signal.SIGTERM, self.handle_signal)
        signal.signal(signal.SIGINT, self.handle_signal)
        signal.signal(signal.SIGUSR1, self.handle_signal)
        signal.signal(signal.SIGCHLD, self.handle_sigchld)

    def handle_signal(self, signum, frame):
        """Graceful shutdown handler"""
        if signum == signal.SIGUSR1:
             if 'entrypoint' in self.processes and self.processes['entrypoint'].poll() is None:
                 self.processes['entrypoint'].send_signal(signum)
        else:
            self.shutdown_requested = True
            for name, proc in self.processes.items():
                if proc.poll() is None:
                    proc.send_signal(signum)
            sys.exit(0)

    def handle_sigchld(self, signum, frame):
        """On Listener death → restart. On  Entrypoint death → shutdown"""
        # Check entrypoint status first
        if 'entrypoint' in self.processes and self.processes['entrypoint'].poll() is not None:
            self.handle_signal(signal.SIGTERM, None)
            return
        # Handle listener restart
        if 'listener' in self.processes and self.processes['listener'].poll() is not None:
            if not self.shutdown_requested:
                self.start(self.listener)

    def start(self, child):
        """Generic process starter with Docker log passthrough for stdout and stderr"""
        self.processes[child] = subprocess.Popen(
            ['/usr/bin/bash', f'/usr/local/sbin/{child}.sh'],
            stdin=subprocess.PIPE if child == 'listener' else None,
            stdout=sys.stdout,
            stderr=sys.stderr,
            text=True,
            bufsize=1
        )
        return self.processes[child]

    def handle_socket_requests(self):
        """Forward socket messages to listener's stdin"""
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.bind(str(self.socket_path))
            sock.listen(5)
            os.chmod(self.socket_path, 0o666)
            
            while not self.shutdown_requested:
                try:
                    conn, _ = sock.accept()
                    with conn:
                        request = conn.recv(1024).decode().strip()
                        if (listener := self.processes.get('listener')) and request:
                            try:
                                listener.stdin.write(request + '\n')
                                listener.stdin.flush()
                            except (BrokenPipeError, OSError):
                                self.start(self.listener)
                except (ConnectionResetError, OSError):
                    continue

    def run(self):
        """Main execution loop"""
        self.start(self.entrypoint)
        self.start(self.listener)
        
        # Socket handler thread
        threading.Thread(
            target=self.handle_socket_requests,
            daemon=True
        ).start()

        # Main monitoring loop
        while not self.shutdown_requested:
            if self.processes['entrypoint'].poll() is not None:
                self.handle_signal(signal.SIGTERM, None)
            time.sleep(1)

if __name__ == '__main__':
    ContainerSupervisor().run()
