class Pty
  class IO < IO::FileDescriptor
    getter temp_closed = Atomic(Int16).new 0

    def self.new(path : Path | String)
      fd = Crystal::System::File.open(path.to_s, "r+", 0o600)
      super(fd)
    end

    private def read_with_error_handling(slice : Bytes, error_message : String)
      loop do
        bytes_read = LibC.read(fd, slice, slice.size)
        if bytes_read == -1
          case Errno.value
          when Errno::EAGAIN, Errno::EWOULDBLOCK
            wait_readable
            next
          when Errno::EINTR
            next # Retry if interrupted by signal
          when Errno::EBADF, Errno::EIO
            return 0 # Handle PTY-specific errors
          else
            raise IO::Error.new(error_message)
          end
        end
        return bytes_read
      end
    end

    protected def unbuffered_read(slice : Bytes)
      # STDOUT.puts "#{self.class} #{fd} ubuf read #{slice.bytesize}"
      #    return 0 if @temp_closed.get == 1

      read_with_error_handling(slice, "Error reading file")
      #     super(slice)
    end

    def tcflush : Nil
      r = C.tcflush(fd, C::TCIOFLUSH)
      raise Error.from_errno("tcflush") unless r == 0
    end
  end
end
