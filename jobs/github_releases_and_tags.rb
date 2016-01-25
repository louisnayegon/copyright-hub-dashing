require 'octokit'

config = YAML::load_file('github.yml')

headers = [
  {
    cols: [
      {
        colspan: 1,
        rowspan: 1,
        value: 'Name'
      },
      {
        colspan: 1,
        rowspan: 1,
        value: 'Last Release'
      },
      {
        colspan: 1,
        rowspan: 1,
        value: 'Last Tag'
      }
    ]
  }
]

last_rows = []

SCHEDULER.every '1m', :first_in => 0 do |job|
  client = Octokit::Client.new(
             :login => config['login'],
             :password => config['password']
           )
  rows = []
  odd_row = true

  config['repositories'].each do |name|
    latest_release = client.latest_release(name)
    tags = client.tags(name)
    latest_release_tag = tags.find {|i| i[:name] == latest_release.tag_name }
    latest_tag = tags[0]
    row_class = odd_row ? 'odd-row' : 'even-row'
    master_sha = client.commits(name)[0][:sha][0...7]
    release_sha = latest_release_tag[:commit][:sha][0...7]
    tag_sha = latest_tag[:commit][:sha][0...7]
    odd_row = !odd_row

    rows.concat(
      [
        {
          class: row_class,
          cols: [
            {
              colspan: 1,
              rowspan: 1,
              value: name.split('/')[1]
            },
            {
              colspan: 1,
              rowspan: 1,
              value: latest_release.tag_name
            },
            {
              colspan: 1,
              rowspan: 1,
              value: latest_tag.name
            }
          ]
        },
        {
          class: row_class,
          cols: [
            {
              colspan: 1,
              rowspan: 1,
              value: master_sha
            },
            {
              colspan: 1,
              rowspan: 1,
              value: release_sha,
              class: master_sha!=release_sha ? 'brag-cell-amber' : ''
            },
            {
              colspan: 1,
              rowspan: 1,
              value: tag_sha,
              class: master_sha!=tag_sha ? 'brag-cell-amber' : ''
            }
          ]
        }
      ]
    )
  end

  if last_rows != rows
    last_rows = rows
    send_event('github_releases_and_tags', {
      title: 'Copyrigt Hub Releases And Tags',
      hrows: headers,
      rows: rows
    })
  end
end
