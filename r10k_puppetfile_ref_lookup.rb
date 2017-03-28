require 'puppet'
require 'puppet/pops/lookup/lookup_adapter'

# Make a reference to the original mod. We'll need this because
# it'll be overridden when RefLookup is included.
class R10K::Puppetfile::DSL
  alias_method :original_mod, :mod
end

module R10K::Puppetfile::RefLookup

  # We're going to be using Puppet, so make sure it's up and ready
  unless $puppet_initialized
    Puppet.initialize_settings
    Puppet.initialize_facts
    $puppet_initialized = true
  end

  class PuppetfileLookupAdapter < Puppet::Pops::Lookup::LookupAdapter
    def initialize(compiler)
      super
      set_global_only
    end
  end

  class HieraAdapter
    attr_accessor :config_path, :hiera

    def initialize(config_path)
      @config_path = File.absolute_path(config_path)
      unless File.exist?(@config_path)
        raise RuntimeError, "Unable to find a hiera.yaml at '#{@config_path}'"
      end
    end

    def lookup(key, scope)
      PuppetfileLookupAdapter.adapt(scope.compiler) { |adapter| adapter.set_global_hiera_config_path(config_path) }
      Puppet.override({:loaders => scope.compiler.loaders}) do
        invocation = Puppet::Pops::Lookup::Invocation.new(
          scope, Puppet::Pops::EMPTY_HASH, Puppet::Pops::EMPTY_HASH, true, PuppetfileLookupAdapter)
        Puppet::Pops::Lookup.lookup(key, nil, nil, true, nil, invocation)
      end
    end
  end

  # Cached handle for querying Hiera
  def lookup(key, hiera_config, scope = self.scope)
    unless @adapter && @adapter.config_path == hiera_config
      @adapter = HieraAdapter.new(hiera_config)
    end
    @adapter.lookup(key, scope)
  end

  def new_scope
    node = Puppet::Node.new('puppetfile')
    node.environment = Puppet.lookup(:current_environment)
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.topscope
  end

  def scope
    @scope ||= new_scope
  end

  def fallback_scope
    @fallback_scope ||= new_scope
  end

  def branch_name
    File.basename(@librarian.basedir)
  end

  # Patch mod() to support automatically using lookup() to find the ref
  # version for a module.
  def mod(name, args = nil)
    return original_mod(name, args) unless args.include?(:ref_lookup)

    hiera_config = File.join(@librarian.basedir, 'hiera.yaml')

    ref = lookup(args[:ref_lookup], hiera_config, scope) ||
          lookup(args[:ref_lookup], hiera_config, fallback_scope) ||
          args[:ref_default]

    args.delete(:ref_lookup)
    args.delete(:ref_default)

    if ref.nil?
      raise "Unable to look up version for #{name}"
    elsif args.empty?
      args = ref
    else
      args[:ref] = ref
    end

    @librarian.logger.info "  Lookup returned #{ref} for #{name}"
    original_mod(name, args)
  end
end

