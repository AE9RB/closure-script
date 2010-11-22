require 'test_helper'

class BeanShellTest < Test::Unit::TestCase
  
  BEANSHELL = Googly::BeanShell.new

  def test_basic_stdout
    5.times do
      assert_equal ["pass\n",''], BEANSHELL.run('System.out.println("pass");')
    end
  end

  def test_basic_stderr
    # STDERR is read on its own thread and Java can be funky with flushing buffers
    # This test should be able to pass 50000 times (to be done manually as needed)
    5.times do
      assert_equal ['', "pass\n"], BEANSHELL.run('System.err.println("pass");')
    end
  end
  
end

