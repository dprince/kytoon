module Kytoon

module XMLUtil

  def self.element_text(dom, name)
    if dom.elements[name]
      return dom.elements[name].text
    else
      return nil
    end
  end

end

end
