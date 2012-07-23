module Kytoon

class Version
  KYTOON_ROOT = File.dirname(File.expand_path("../", File.dirname(__FILE__)))
  VERSION = IO.read(File.join(KYTOON_ROOT, 'VERSION'))
end

end
