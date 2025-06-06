require "socket"

class Pty
  class IO < IO::FileDescriptor
    getter temp_closed = Atomic(Int16).new 0

    def self.new(path : Path | String)
      fd = Crystal::System::File.open(path.to_s, "r+", 0o600, true)  # true for blocking mode
      super(fd)
    end

    protected def unbuffered_read(slice : Bytes)
      loop do
        begin
          bytes_read = Crystal::EventLoop.current.read(self, slice)
          return bytes_read
        rescue ex : IO::Error
          # Handle specific error cases for PTY
          if ex.responds_to?(:errno)
            errno = ex.errno
            if errno == Errno::EBADF || errno == Errno::EIO
              return 0
            elsif errno == Errno::EAGAIN
              # If would block, wait and try again
              next
            end
          end
          # Re-raise other errors
          raise ex
        end
      end
    end

    def tcflush : Nil
      r = C.tcflush(fd, C::TCIOFLUSH)
      raise Error.from_errno("tcflush") unless r == 0
    end
  end
end
