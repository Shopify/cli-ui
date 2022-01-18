# typed: true

class IO
  sig { returns(IO) }
  def self.console; end

  sig { returns([Integer, Integer]) }
  def winsize; end

  sig { type_parameters(:U).params( block: T.proc.returns(T.type_parameter(:U))).returns(T.type_parameter(:U)) }
  def noecho(&block); end
end
