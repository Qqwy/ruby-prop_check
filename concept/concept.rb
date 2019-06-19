class Generator
  @@generator_size = 1
  @@generator_rng = Random.new
  @@generating_mode = false

  def initialize(&implementation)
    @implementation = implementation
  end

  def self.generator_rng
    @@generator_rng
  end

  def self.generator_rng=(other)
    @@generator_rng = other
  end

  def self.generator_size
    @@generator_size
  end

  def self.resized(scale, &block)
    old_scale = @@generator_size
    @@generator_size = scale
    res = block.call
    @@generator_size = old_scale
    res
  end

  def map(&block)
    Generator.new { val = self.call; block.call(val) }
  end

  def self.generator_size=(other)
    @@generator_size = other
  end

  def self.in_generating_mode
    old_mode = @@generating_mode
    @@generating_mode = true
    res = yield
    @@generating_mode = old_mode
    res
  end

  def self.in_normal_mode
    old_mode = @@generating_mode
    @@generating_mode = false
    res = yield
    @@generating_mode = old_mode
    res
  end

  def call
    # instance_exec(&@implementation)
    Generator.in_normal_mode do
      res = @implementation.call
      return res.call if res.is_a?(Generator)

      res
    end
  end

  def self.new(*args, &block)
    if @@generating_mode
      LazyProxy.new { super.call }
    else
      super
    end
  end
end

module GeneratorStuff
  def generator_size
    Generator.generator_size
  end

  def generator_rng
    Generator.generator_rng
  end

  def integer_between(range)
    Generator.new { generator_rng.rand(range) }
  end

  def integer
    Generator.new { integer_between(-generator_size..generator_size) }
  end

  def resize(scale, generator)
    Generator.new { Generator.resized(scale) { generator } }
  end

  def nonnegative_integer
    Generator.new { integer.map(&:abs) }
  end

  private def fraction(a, b, c)
    a.to_f + b.to_f / ((c.to_f.abs) + 1.0)
  end

  def float
    Generator.new { fraction(integer, integer, integer) }
  end

  def char
    Generator.new do
      integer_between(32..128).map(&:chr)
    end
  end

  def array(elem)
    Generator.new do
      nonnegative_integer.map do |len|
        (0..len).map do
          elem.dup.call
        end
      end
    end
  end

  def string
    Generator.new do
      array(char).map(&:join)
    end
  end
end

class LazyProxy < BasicObject
  def initialize(&impl)
    @impl = impl
    @evaluated = false
    @res = nil
  end

  def __evaluate__
    return @res if @evaluated

    @res = @impl.call
    @evaluated = true

    @res
  end

  def __clone__
    ::LazyProxy.new(&@impl)
  end

  def method_missing(method, *args, &block)
    __evaluate__
    # ::Kernel.puts "Call to `#{method}(#{args.map(&:inspect).join(', ')})` was proxied"
    @res.send(method, *args, &block)
  end

  def respond_to?(*args)
    __evaluate__
    @res.respond_to?(*args)
  end
end

class Property
  def initialize
    puts "Yay"
    @size = 1
  end

  def check(&block)
    puts "Checking property..."
      (1..1000).each do |iteration|
        Generator.in_generating_mode do
        Generator.generator_size = iteration
        # res = instance_exec(&block)
        res = block.call
        puts "Res is: #{res}"
      end
    end
  end
end

# module GeneratorStuff

#   def integer_between(range)
#     raise "Something that is not a range was passed" unless range.is_a?(Range)
#     LazyProxy.new {
#       rand(range)
#     }
#   end

#   def integer
#     integer_between(-@size..@size)
#   end

#   def nonnegative_integer
#     LazyProxy.new do
#       integer.abs
#     end
#   end

#   private def fraction(a, b, c)
#     a.to_f + b.to_f / ((c.to_f.abs) + 1.0)
#   end

#   def float
#     LazyProxy.new do
#       fraction(integer, integer, integer)
#     end
#   end

#   def char
#     LazyProxy.new do
#       integer_between(32..128).chr
#     end
#   end

#   def array(elem)
#     LazyProxy.new do
#       len = nonnegative_integer
#       (0..len).map do
#         elem.__clone__
#       end
#     end
#   end

#   def string
#     LazyProxy.new do
#       array(char).join
#     end
#   end

#   def resize(num, generator)
#     oldsize = @size
#     LazyProxy.new {
#       @size = oldsize * num
#       res = generator.__evaluate__
#       @size = oldsize
#       res
#     }
#   end
# end

def check_property(&block)
  # Property.new.instance_exec(block)
  Property.new.check(&block)
end

# def string
#   "foo"
# end

class Baz
  include GeneratorStuff
  def baz
    string
  end

  def call
    check_property do |x = resize(20, integer), y = nonnegative_integer, z = baz|
      puts x
      puts y
      puts z

      # puts x.class
      # puts y.class
      # puts z.class
      # puts x > y
      x > y == z
    end
  end
end

Baz.new.call
