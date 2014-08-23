require_relative 'db_connection'
require 'active_support/inflector'
#NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
#    of this project. It was only a warm up.

class SQLObject

  def self.columns
    cols = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL
    cols[0].map { |column| column.to_sym }
  end

  def self.finalize!
    self.columns.each do |column|
      define_method(column) do
        self.attributes[column]
      end

      define_method("#{column}=") do |value|
        puts "self.attributes = #{self.attributes}"
        # attr_hash = self.attributes
        self.attributes[column] = value
        # attr_hash = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name.nil? ? self.to_s.tableize : @table_name
  end

  def self.all
    table = self.table_name
    rows = DBConnection.execute(<<-SQL)
    SELECT
      *
    FROM
      #{table}
    SQL
    self.parse_all(rows)
  end

  def self.parse_all(results)
    results.map do |row|
      self.new(row)
    end
  end

  def self.find(id)
    row = DBConnection.execute(<<-SQL, id)
      SELECT 
        *
      FROM
        #{self.table_name}
      WHERE
        id = ?
    SQL
    parse_all(row).first
  end

  def attributes
    @attributes ||= {}
  end

  def insert
    col_names = self.class.columns.join(', ')
    num_cols = self.class.columns.count
    q_marks = (["?"] * num_cols).join(', ')

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{q_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def initialize(params = {})
    cols = self.class.columns
    params.keys.each do |name|
      if cols.include?(name.to_sym)
        attributes[name.to_sym] = params[name] 
      else
        raise "unknown attribute '#{name}'"
      end
    end
  end

  def save
    self.id.nil? ? self.insert : self.update
  end

  def update
    cols = self.class.columns.map { |column| column.to_s + ' = ?' }.join(', ')
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{cols}
      WHERE
        id = ? 
    SQL
  end

  def attribute_values
    self.class.columns.map { |column| send(column) }
  end
end
