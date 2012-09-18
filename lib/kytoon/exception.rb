class KytoonException < StandardError
end

class ConfigException < KytoonException
end

class NoServerGroupExists < KytoonException
end
