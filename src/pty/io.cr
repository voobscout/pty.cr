class Pty
  class IO < IO::FileDescriptor
    getter temp_closed = Atomic(Int16).new 0

    def self.new(path : Path | String)
      fd = Crystal::System::File.open(path.to_s, "r+", 0o600)
      super(fd)
    end

    protected def unbuffered_read(slice : Bytes)
      evented_read(slice, "Error reading file") do
        LibC.read(fd, slice, slice.size).tap do |return_code|
          if return_code == -1 && (Errno.value == Errno::EBADF || Errno.value == Errno::EIO)
            return 0
          else
          end
        end
      end
      #     super(slice)
    end

    def tcflush : Nil
      r = C.tcflush(fd, C::TCIOFLUSH)
      raise Error.from_errno("tcflush") unless r == 0
    end
  end
end
