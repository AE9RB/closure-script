require 'test_helper'

class BeanShellTest < Test::Unit::TestCase
  
  BEANSHELL = Googly::BeanShell.new

  def test_basic_run
    3.times do
      assert_equal ["pass\n",''], BEANSHELL.run('System.out.println("pass");')
    end
  end
  
end

