require 'test_helper'

describe Closure::Compiler do
  before do
    @util = Closure::Compiler::Util
  end

  # Closure::Compiler.compile is primarily supported with functional tests.
  describe 'compile' do
    it 'does not lock up when no --js file specified ' do
      args = %w{ --js_output_file jstest.out }
      Closure::Compiler.compile(args)
      # simply not getting stuck in an endless loop is passing
      assert true
    end
  end

  describe 'Util.expand_paths' do
    it 'expands relative options to the new path' do
      args = %w{
        --externs rails.ujs
        --create_source_map ../map.js
        --js /plugh/file.js
      }
      @util.expand_paths(args, '/abc/xyzzy').must_equal %w{
        --externs /abc/xyzzy/rails.ujs
        --create_source_map /abc/map.js
        --js /plugh/file.js
      }
    end
  end
  
  describe 'Util.arg_values' do
    it 'extracts argument values' do
      args = %w{
        --js_output_file jstest.out
        --js not_a_real_file.js
        --js still_fake.js
      }
      @util.arg_values(args, '--js').must_equal %w{
        not_a_real_file.js
        still_fake.js
      }
      @util.arg_values(args, '--js_output_file').must_equal %w{
        jstest.out
      }
      @util.arg_values(args, ['--js', '--js_output_file']).must_equal %w{
        jstest.out
        not_a_real_file.js
        still_fake.js
      }
    end
  end
  
  describe 'Util.namespace_augment' do
    it 'expands a namespace' do
      sources = Closure::Sources.new
      sources.add File.join Closure.base_path, 'scripts'
      args = %w{
        --ns rails.ujs
      }
      @util.namespace_augment(args, sources)
      args.wont_include '--ns'
      args.wont_include 'rails.ujs'
      args.length.must_be :>, 50
    end
  end

  describe 'Util.module_augment' do
    it "fills in counts" do
      args = %w{
        --module app:*
        --js not_a_real_file.js
        --js still_fake.js
      }
      expected_args = %w{
        --module app:2
        --js not_a_real_file.js
        --js still_fake.js
      }
      @util.module_augment(args)
      args.must_equal expected_args
    end

    it "builds array of module info" do
      args = %w{
        --module app:*
        --js not_a_real_file.js
        --module stuff:*:app
        --js still_fake.js
      }
      expected_mods = [{
        :name => 'app',
        :files => %w{not_a_real_file.js},
        :requires => %w{}
      },{
        :name => 'stuff',
        :files => %w{still_fake.js},
        :requires => %w{app}
      }]
      @util.module_augment(args).must_equal expected_mods
    end

    it "disallows mixing --module formats" do
      args = %w{
        --module app:*
        --js not_a_real_file.js
        --module sets:1
        --js still_fake.js
      }
      proc { @util.module_augment(args) }.must_raise RuntimeError
    end

    it "disallows --js before --module x:*" do
      args = %w{
        --js not_a_real_file.js
        --module app:*
        --js still_fake.js
      }
      proc { @util.module_augment(args) }.must_raise RuntimeError
    end

    it "disallows --module with an automatic count of 0" do
      args = %w{
        --module app:*
      }
      proc { @util.module_augment(args) }.must_raise RuntimeError
    end

  end

end
