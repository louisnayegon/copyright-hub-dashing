require 'octokit'
require 'aws-sdk'

CONFIG        = YAML::load_file('github.yml')
GITHUB_CONFIG = CONFIG['github']
AWS_CONFIG    = CONFIG['aws']

HEADERS = [
  {
    cols: [
      {
        colspan: 1,
        rowspan: 1,
        value: 'Repository Name'
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
      },
       {
         colspan: 1,
         rowspan: 1,
         value: 'Last Deploy'
       }
    ]
  }
]

last_rows = []


def github_info(github_client, repo_name)
  latest_release = github_client.latest_release(repo_name)
  tags = github_client.tags(repo_name)
  latest_release_tag = tags.find {|i| i[:name] == latest_release.name }
  latest_tag = tags[0]
  commits = github_client.commits(repo_name)
  master_sha = commits[0][:sha][0...7]
  release_sha = latest_release_tag[:commit][:sha][0...7]
  tag_sha = latest_tag[:commit][:sha][0...7]

  return latest_release, latest_tag, master_sha, release_sha, tag_sha
end


def aws_info(s3_client, s3_location)
  bucket_name = s3_location.split('/')[0]
  directory = s3_location[bucket_name.length+1..-1] + '/'
  dirs = s3_client.list_objects(bucket: bucket_name, prefix: directory, delimiter:'/').common_prefixes
  dirs = dirs.sort_by(&:prefix).reverse!
  if dirs.empty?
    last_deploy = ''
  else
    last_deploy = dirs[0][:prefix].split('/')[-1]
  end

  return last_deploy
end


SCHEDULER.every CONFIG['refresh'], :first_in => 0 do |job|
  github_client = Octokit::Client.new(
                    :login => GITHUB_CONFIG['login'],
                    :password => GITHUB_CONFIG['password']
                  )
  s3_client = Aws::S3::Client.new(region: AWS_CONFIG['region'])

  rows = []
  odd_row = true

  CONFIG['components'].each do |component|
    repo_name = component['repo_name']
    latest_release, latest_tag, master_sha, release_sha, tag_sha = github_info(github_client, repo_name)

    if component.has_key?('s3_location')
      s3_location = component['s3_location']
      last_deploy = aws_info(s3_client, s3_location)
    else
      last_deploy = ''
    end

    row_class = odd_row ? 'odd-row' : 'even-row'
    odd_row = !odd_row
    rows.concat(
      [
        {
          class: row_class,
          cols: [
            {
              colspan: 1,
              rowspan: 1,
              value: repo_name.split('/')[1]
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
            },
            {
              colspan: 1,
              rowspan: 1,
              value: last_deploy,
              class: (last_deploy!=latest_release.tag_name) && (not last_deploy.empty?) ? 'brag-cell-amber' : row_class
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
              class: master_sha!=release_sha ? 'brag-cell-amber' : row_class
            },
            {
              colspan: 1,
              rowspan: 1,
              value: tag_sha,
              class: master_sha!=tag_sha ? 'brag-cell-amber' : row_class
            },
            {
              colspan: 1,
              rowspan: 1,
              value: ''
            }
          ]
        }
      ]
    )
  end

  if last_rows != rows
    last_rows = rows
    send_event('github_releases_and_tags', {
      title: 'Copyright Hub Releases, Tags And Deployments',
      hrows: HEADERS,
      rows: rows
    })
  end
end
