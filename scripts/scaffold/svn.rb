require 'rexml/document'
require 'thread'

class Closure::Svn
  
  # Repositories are held in global class variable.
  # Checking out or updating runs in a background thread.
  # repo = Closure::Svn['lib-folder', 'http://svn.example.org/trunk']
  # repo.update if repo.update_available?
  @repos ||= {}
  def self.[](path, url)
    @repos[path] ||= new path, url
  end
  
  # Configurable Subversion shell command
  def self.svn; @svn ||= 'svn'; end
  def self.svn=(svn); @svn = svn; end

  def initialize(path, url)
    @semaphore ||= Mutex.new
    @status = nil
    @path = path
    @url = url
    @updating_to = nil
    @log = nil
  end
  
  attr_reader :status
  attr_reader :path
  attr_reader :url
  attr_reader :updating_to
  attr_accessor :log

  # Update or checkout a Subverion repository.
  # Closure Script is thread-safe and so is this.
  # Although the locks in Subversion would prevent it
  # from corrupting (one would hope), we don't want our
  # global object to be in an indeterminate state with two 
  # threads running because submit was hit twice.
  def update(revision='HEAD')
    @semaphore.synchronize do
      return if @status
      @status = :starting
      Thread.new do
        @updating_to = revision
        @local_revision = 'UPDATING'
        @log = "Updating to revision #{updating_to}.  Stand by..."
        if File.exist? path
          @status = :update
          @log = `#{self.class.svn.dump} update --revision #{revision.dump} #{path.dump} 2>&1`
        else
          @status = :checkout
          @log = `#{self.class.svn.dump} checkout --revision #{revision.dump} #{url.dump} #{path.dump} 2>&1`
        end
        @status = nil
        @updating_to = nil
        @local_revision = nil
      end
    end
  end
  
  def info(location)
    p "Checking: #{location}" #TODO
    doc = ::REXML::Document.new `#{self.class.svn.dump} info --xml #{location.dump}`
    source = doc.root.elements['//info/entry/url'].text
    doc.elements.each('info/entry/commit') do |element|
      return {:url => source, :revision => element.attributes['revision']}
    end
  rescue
    return {:url => nil, :revision => 'ERROR'}
  end
    
  def local_revision
    return @local_revision if @local_revision
    local_info = info(path)
    @found_url, @local_revision = local_info[:url], local_info[:revision]
    @local_revision = 'NEW' unless File.exist?(path)
    @local_revision
  end

  def url
    local_revision # sets real @url from info, if found
    @found_url || @url
  end
  
  def remote_revision
    begin # Check every 12 hours
      raise if Time.now - @remote_revision_checked > 43200
    rescue
      @remote_revision = nil
      @remote_revision_checked = Time.now
    end
    @remote_revision ||= info(url)[:revision]
  end
  
  def update_available?
    return false if remote_revision == 'ERROR'
    remote_revision != local_revision
  end
  
end