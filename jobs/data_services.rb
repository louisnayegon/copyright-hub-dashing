require 'octokit'
require 'aws-sdk'
require 'json'
require 'curb'

class DataServices
  attr_reader :CONFIG, :HEADERS, :last_rows
  attr_writer :last_rows
  def initialize()
    @CONFIG = YAML::load_file('github.yml')
    @HEADERS = [
      {
        cols: [
          {
            colspan: 1,
            rowspan: 1,
            value: 'Service Name'
          },
          {
            colspan: 1,
            rowspan: 1,
            value: 'Stage'
          },
          {
            colspan: 1,
            rowspan: 1,
            value: 'Production'
          }
        ]
      }
    ]
    @last_rows = []
  end
end

data_services = DataServices.new

def service_state(url)
  cu = Curl::Easy.new(url)
  cu.follow_location = true
  cu.http_get() rescue return false
  return true
end


SCHEDULER.every data_services.CONFIG['refresh'], :first_in => 0 do |job|
  rows = []
  odd_row = true

  data_services.CONFIG['data_services'].each do |service|
    name = service['name']

    row_class = odd_row ? 'odd-row' : 'even-row'
    odd_row = !odd_row

    state_stage = 'UNDEFINED'
    class_stage = 'brag-cell-amber'
    if service.has_key?('url_stage')
      url = service['url_stage']
      if service_state(url)
        state_stage = 'ACTIVE'
        class_stage = row_class
      else
        state_stage = 'UNDEFINED'
        class_stage = 'brag-cell-red'
      end
    end

    state_prod = 'UNDEFINED'
    class_prod = 'brag-cell-amber'
    if service.has_key?('url_prod')
      url = service['url_prod']
      if service_state(url)
        state_prod = 'ACTIVE'
        class_prod = row_class
      else
        state_prod = 'UNDEFINED'
        class_prod = 'brag-cell-red'
      end
    end

    rows.concat(
      [
        {
          class: row_class,
          cols: [
            {
              colspan: 1,
              rowspan: 1,
              value: name
            },
            {
              colspan: 1,
              rowspan: 1,
              value: state_stage,
              class: class_stage
            },
            {
              colspan: 1,
              rowspan: 1,
              value: state_prod,
              class: class_prod
            }
          ]
        }
      ]
    )
  end

  if data_services.last_rows != rows
    data_services.last_rows = rows
    send_event('data_services', {
      title: 'Data Service State',
      hrows: data_services.HEADERS,
      rows: rows
    })
  end
end
