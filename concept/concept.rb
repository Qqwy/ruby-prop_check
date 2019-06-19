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

  def __reevaluate__
    @evaluated = false
    __evaluate__
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

  def integer_between(range)
    raise "Something that is not a range was passed" unless range.is_a?(Range)
    LazyProxy.new {
      rand(range)
    }
  end

  def integer
    integer_between(-@size..@size)
  end

  def nonnegative_integer
    LazyProxy.new do
      integer.abs
    end
  end

  private def fraction(a, b, c)
    a.to_f + (b.to_f / (c.to_f.abs) + 1.0)
  end

  def float
    LazyProxy.new do
      fraction(integer, integer, integer)
    end
  end

  def char
    LazyProxy.new do
      integer_between(32..255).chr
    end
  end

  def array(elem)
    LazyProxy.new do
      len = nonnegative_integer
      (0..len).map do
        elem.__reevaluate__
      end
    end
  end

  def string
    LazyProxy.new do
      array(char).join
    end
  end

  def resize(num, generator)
    oldsize = @size
    LazyProxy.new {
      @size = oldsize * num
      res = generator.__evaluate__
      @size = oldsize
      res
    }
  end

  def check(&block)
    puts "Checking property..."
    (1..1000).each do |iteration|
      @size = iteration
      res = instance_exec(&block)
      puts "Res is: #{res}"
    end
  end
end

def check_property(&block)
  # Property.new.instance_exec(block)
  Property.new.check(&block)
end

# def string
#   "foo"
# end

check_property do |x = resize(20, integer), y = float, z = string|
  puts x
  puts y
  puts z

  # puts x.class
  # puts y.class
  # puts z.class
  # puts x > y
  x > y == z
end
