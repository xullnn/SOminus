class SOMBase
  # create an obj in memory
  def initialize(attr_hash={})
    attr_hash.each do |id, attrs|
      self.id = id
      attrs.each { |k, v| self.send("#{k}=", v) }
    end
    self
  end

  # write new data into yaml file
  def self.create(params)
    hash = { new_id_of(data_name) => params }
    File.open(File.join(data_path, "#{data_name.to_s}.yaml"), "a+") do |f|
      f.write(Psych.dump(hash.to_h).delete_prefix("---\n"))
    end
    new(hash)
  end

  # load all data of a certain type, wrap every datum into a Ruby object
  # return an array of objects
  def self.all
    return [] unless load_data_of(data_name)
    load_data_of(data_name).map do |id, attrs|
      new({ id => attrs })
    end
  end

  # return array that contains all matched objects
  def self.find_all_by(attr, value)
    all.select { |obj| obj.send(attr) == value }
  end

  # return an obj with set attrs
  def self.find_by(attr, value)
    all.find { |obj| obj.send(attr) == value }
  end

  # return a symbol based on current class name e.g :users, :answers
  def self.data_name
    (name.downcase + "s").to_sym
  end

  def self.last
    all.last
  end

  # find the biggest id of a certain type
  # return a new id + 1
  def self.new_id_of(type)
    valid_types(type)
    data = load_data_of(type)
    return "1" unless data
    max_id = data.keys.map(&:to_i).max
    (max_id + 1).to_s
  end

  # load raw data from yaml file, return a nested hash
  # top level key is 'id'
  def self.load_data_of(type)
    filename = type.to_s + ".yaml"
    Psych.load_file(File.join(data_path, filename))
  end

  def self.add_attributes_to(type, default="", *columns)
    # need to add attr_accessor into Object's file
    data = SOMBase.load_data_of(type)
    columns.each do |column|
      data.values.each do |attrs|
        attrs[column.to_s] = default
      end
    end
    File.open(File.join(data_path, "#{type.to_s}.yaml"), "w+") do |f|
      f.write(Psych.dump(data).delete_prefix("---\n"))
    end
  end

  def self.update(id, attrs)
    data = load_data_of(data_name)
    obj_info = data[id]
    attrs.each do |k, v|
      v = v.to_s if v.is_a?(Array)
      obj_info[k] = v
    end
    File.open(File.join(data_path, "#{data_name.to_s}.yaml"), "w+") do |f|
      f.write(Psych.dump(data).delete_prefix("---\n"))
    end
  end
end
