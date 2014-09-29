module Nexus
  class Util

    def self.strip_hash(hash)
      hash.each do |key, value|
        self.strip_hash(value) if value.is_a?(Hash)
        hash.delete(key) if ((value.respond_to?(:empty?) && value.empty?) || value.nil?)
      end
    end

    def self.sym_to_bool(sym)
      nil == sym ? nil : :true == sym
    end
  end
end
