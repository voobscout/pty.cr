class Pty
  class IO < IO::FileDescriptor
    getter temp_closed = Atomic(Int16).new 0

    def self.new(path : Path | String)
      fd = Crystal::System::File.open(path.to_s, "r+", 0o600)
      super(fd)
    end

    # Wait until the file descriptor is readable
    private def wait_readable
      # Use the event loop's wait_readable method
      Crystal::EventLoop.current.wait_readable(fd)
    rescue ex : IO::Error
      # Handle specific errors that might occur during wait
      if ex.errno == Errno::EBADF || ex.errno == Errno::EIO
        return false
      else
        raise ex
      end
    end

    # Wait until the file descriptor is writable
    private def wait_writable
      # Use the event loop's wait_writable method
      Crystal::EventLoop.current.wait_writable(fd)
    rescue ex : IO::Error
      # Handle specific errors that might occur during wait
      if ex.errno == Errno::EBADF || ex.errno == Errno::EIO
        return false
      else
        raise ex
      end
    end

    protected def unbuffered_read(slice : Bytes)
      # STDOUT.puts "#{self.class} #{fd} ubuf read #{slice.bytesize}"
      #    return 0 if @temp_closed.get == 1

      loop do
        bytes_read = LibC.read(fd, slice, slice.size)
        if bytes_read == -1
          case Errno.value
          when Errno::EAGAIN, Errno::EWOULDBLOCK
            # Wait until the file descriptor is readable
            if wait_readable
              next
            else
              return 0
            end
          when Errno::EINTR
            next # Retry if interrupted by signal
          when Errno::EBADF, Errno::EIO
            return 0 # Handle PTY-specific errors
          else
            raise IO::Error.new("Error reading file")
          end
        end
        return bytes_read
      end
    end

    # Perform a write operation with proper error handling
    protected def unbuffered_write(slice : Bytes)
      total_written = 0
      while total_written < slice.size
        bytes_written = LibC.write(fd, slice + total_written, slice.size - total_written)
        if bytes_written == -1
          case Errno.value
          when Errno::EAGAIN, Errno::EWOULDBLOCK
            # Wait until the file descriptor is writable
            if wait_writable
              next
            else
              return total_written
            end
          when Errno::EINTR
            next # Retry if interrupted by signal
          else
            raise IO::Error.new("Error writing to file")
          end
        end
        total_written += bytes_written
      end
      total_written
    end

    def tcflush : Nil
      r = C.tcflush(fd, C::TCIOFLUSH)
      raise Error.from_errno("tcflush") unless r == 0
    end
  end
end
