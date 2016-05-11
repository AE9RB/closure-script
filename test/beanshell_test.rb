require 'test_helper'

class BeanShellTest < Minitest::Test

  BEANSHELL = Closure::BeanShell.new

  def test_basic_stdout
    unless defined? JRUBY_VERSION
      5.times do
        assert_equal "pass\n", BEANSHELL.run('System.out.println("pass");')
      end
    end
  end

end
