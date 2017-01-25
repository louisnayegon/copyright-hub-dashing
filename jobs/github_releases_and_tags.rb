require 'octokit'
require 'aws-sdk'
require 'json'
require 'curb'

class GithubReleasesAndTags
  attr_reader :CONFIG, :HEADERS, :last_rows
  attr_writer :last_rows
  def initialize()
    @CONFIG          = YAML::load_file('github.yml')
    @HEADERS = [
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
            value: 'Stage'
          },
          {
            colspan: 1,
            rowspan: 1,
            value: 'Production'
          },
          {
            colspan: 1,
            rowspan: 1,
            value: 'Last Deploy'
          },
          {
            colspan: 1,
            rowspan: 1,
            value: 'Manifest'
          }
        ]
      }
    ]

    last_rows = []
  end
end

releases_and_tags = GithubReleasesAndTags.new

def github_info(github_client, repo_name)
  latest_release = github_client.latest_release(repo_name)
  tags = github_client.tags(repo_name)
  latest_release_tag = tags.find {|i| i[:name] == latest_release.tag_name }
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


def service_info(url)
  cu = Curl::Easy.new(url)
  cu.follow_location = true
  ret = ''
  cu.http_get() rescue return ret
  response = JSON.parse(cu.body_str)
  if response.has_key?('data')
    data = response['data']
    if data.has_key?('version')
      ret = data['version']
    end
  end
  return ret
end


def read_manifest(github_client, repo_name, file_name)
  content = github_client.contents(repo_name, :path => file_name)[:content]
  return JSON.parse(Base64.decode64(content))
end


SCHEDULER.every releases_and_tags.CONFIG['refresh'], :first_in => 0 do |job|
  github_client = Octokit::Client.new(
                    :login => releases_and_tags.CONFIG['github']['login'],
                    :password => releases_and_tags.CONFIG['github']['password']
                  )
  s3_client = Aws::S3::Client.new(
                region: releases_and_tags.CONFIG['aws']['region'],
                credentials: Aws::SharedCredentials.new(profile_name: releases_and_tags.CONFIG['aws']['profile'])
              )

  rows = []
  odd_row = true

  manifest = read_manifest(github_client, releases_and_tags.CONFIG['manifest']['repo_name'], releases_and_tags.CONFIG['manifest']['file_name'])

  releases_and_tags.CONFIG['components'].each do |component|
    repo_name = component['repo_name']
    latest_release, latest_tag, master_sha, release_sha, tag_sha = github_info(github_client, repo_name)

    s3_location = component['s3_location']
    location_split = s3_location.split('/')
    last_deploy = aws_info(s3_client, s3_location)

    stage_version = ''
    if component.has_key?('url_stage')
      url = component['url_stage']
      stage_version = service_info(url)
    end

    production_version = ''
    if component.has_key?('url_prod')
      url = component['url_prod']
      production_version = service_info(url)
    end

    manifest_version = ''

    part = location_split[2]
    if manifest.key?(location_split[1])
      manifest_version = manifest[location_split[1]][part]['version']
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
              value: stage_version,
              class: (stage_version!=latest_release.tag_name) && (not stage_version.empty?) ? 'brag-cell-amber' : row_class
            },
            {
              colspan: 1,
              rowspan: 1,
              value: production_version,
              class: (production_version!=latest_release.tag_name) && (not production_version.empty?) ? 'brag-cell-amber' : row_class
            },
            {
              colspan: 1,
              rowspan: 1,
              value: last_deploy,
              class: (last_deploy!=latest_release.tag_name) && (not last_deploy.empty?) ? 'brag-cell-amber' : row_class
            },
            {
              colspan: 1,
              rowspan: 1,
              value: manifest_version,
              class: ((manifest_version!=latest_release.tag_name) && (repo_name!=releases_and_tags.CONFIG['manifest']['repo_name'])) ? 'brag-cell-amber' : row_class
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
            },
            {
              colspan: 1,
              rowspan: 1,
              value: ''
            },
            {
              colspan: 1,
              rowspan: 1,
              value: ''
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

  if releases_and_tags.last_rows != rows
    releases_and_tags.last_rows = rows
    send_event('github_releases_and_tags', {
      title: 'Copyright Hub Releases, Tags And Deployments',
      hrows: releases_and_tags.HEADERS,
      rows: rows
    })
  end
end
