# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require_relative 'dynamo'

#
# Owner of tuples.
#
class Owner
  def initialize(aws, login)
    @aws = aws
    @login = login
  end

  def add(entity, time, rel, text)
    raise 'Entity must be of type String' unless entity.is_a?(String)
    raise 'Entity is not formatted right' unless entity =~ /^[a-z ]{3,64}$/
    raise 'Time must be of type Time' unless time.is_a?(Time)
    raise 'Rel must be of type String' unless rel.is_a?(String)
    raise 'Rel is not formatted right' unless rel =~ /^[a-z]+(:[a-z]+)*$/
    raise 'Text must be of type String' unless text.is_a?(String)
    raise 'Text can\'t be empty' if text.empty?
    raise 'Text is too long' unless text.length < 4096
    @aws.put_item(
      table_name: 'curiost-tuples',
      item: {
        'uuid' => SecureRandom.uuid,
        'login' => @login,
        'entity' => entity.downcase,
        'duple' => "#{@login} #{rel}",
        'tuple' => "#{@login} #{rel} #{text[0..128]}",
        'id' => id(entity),
        'rel' => rel,
        'time' => time.to_i,
        'text' => text
      }
    )
  end

  def tuples(query)
    raise 'Query must be of type String' unless query.is_a?(String)
    if query.empty?
      @aws.query(
        table_name: 'curiost-tuples',
        index_name: 'tuples',
        limit: 50,
        consistent_read: false,
        select: 'ALL_ATTRIBUTES',
        scan_index_forward: false,
        expression_attribute_values: {
          ':l' => @login
        },
        key_condition_expression: 'login=:l'
      ).items
    elsif query.include?('=')
      rel, data = query.split(/\s*=\s*/)
      @aws.query(
        table_name: 'curiost-tuples',
        index_name: 'search',
        limit: 50,
        consistent_read: false,
        select: 'ALL_ATTRIBUTES',
        scan_index_forward: false,
        expression_attribute_names: {
          '#t' => 'tuple'
        },
        expression_attribute_values: {
          ':t' => "#{@login} #{rel} #{data}"
        },
        key_condition_expression: '#t=:t'
      ).items
    else
      @aws.query(
        table_name: 'curiost-tuples',
        index_name: 'entities',
        limit: 50,
        consistent_read: false,
        select: 'ALL_ATTRIBUTES',
        expression_attribute_values: {
          ':l' => @login,
          ':e' => query
        },
        key_condition_expression: 'login=:l and begins_with(entity, :e)'
      ).items
    end
  end

  def history(entity)
    raise 'Entity must be of type String' unless entity.is_a?(String)
    raise 'Entity is not formatted right' unless entity =~ /^[a-z ]{3,64}$/
    @aws.query(
      table_name: 'curiost-tuples',
      index_name: 'history',
      limit: 50,
      consistent_read: false,
      select: 'ALL_ATTRIBUTES',
      scan_index_forward: false,
      expression_attribute_values: {
        ':i' => id(entity)
      },
      key_condition_expression: 'id=:i'
    ).items
  end

  private

  def id(entity)
    "#{@login}:#{entity}"
  end
end
