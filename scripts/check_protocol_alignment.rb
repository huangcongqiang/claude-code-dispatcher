#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "optparse"

PROTOCOL_ID = "delivery-governance"
PROTOCOL_VERSION = "1.0.0"
REQUIRED_INVARIANTS = (1..10).map { |number| format("DG-%02d", number) }.freeze
REQUIRED_PACKET_MARKERS = %w[
  protocol
  plan_owner
  lifecycle_owner
  status_projection
  writeback_owner
  implementation_fact_owner
  contract_owner
].freeze
SUPPORTED_SKILLS = %w[
  claude-code-dispatcher
  claude-terra-delivery-loop
  loopx-engineering-manager
  luna-agent-dispatcher
  luna-terra-delivery-loop
  loopx-luna-engineering-manager
].freeze

options = {
  siblings_root: nil,
  require_all: false
}

OptionParser.new do |parser|
  parser.banner = "Usage: check_protocol_alignment.rb [options]"
  parser.on("--siblings-root PATH", "Directory containing sibling skill repositories") do |path|
    options[:siblings_root] = File.expand_path(path)
  end
  parser.on("--require-all", "Fail unless all six supported skill repositories exist") do
    options[:require_all] = true
  end
end.parse!

def sha256(path)
  Digest::SHA256.file(path).hexdigest
end

def frontmatter_value(text, key)
  match = text.match(/\A---\s*$.*?^#{Regexp.escape(key)}:\s*([^\s]+)\s*$.*?^---\s*$/m)
  match && match[1]
end

def validate_repo(repo)
  errors = []
  skill_name = File.basename(repo)
  skill_path = File.join(repo, "SKILL.md")
  protocol_path = File.join(repo, "references", "delivery-governance.md")
  checker_path = File.join(repo, "scripts", "check_protocol_alignment.rb")

  unless File.file?(skill_path)
    return { skill: skill_name, errors: ["missing SKILL.md"] }
  end
  unless File.file?(protocol_path)
    return { skill: skill_name, errors: ["missing references/delivery-governance.md"] }
  end
  errors << "missing scripts/check_protocol_alignment.rb" unless File.file?(checker_path)

  skill_text = File.read(skill_path)
  protocol_text = File.read(protocol_path)
  declared_name = frontmatter_value(skill_text, "name")
  errors << "frontmatter name #{declared_name.inspect} does not match #{skill_name}" unless declared_name == skill_name
  errors << "SKILL.md does not route to references/delivery-governance.md" unless skill_text.include?("references/delivery-governance.md")
  errors << "protocol_id mismatch" unless frontmatter_value(protocol_text, "protocol_id") == PROTOCOL_ID
  errors << "protocol version mismatch" unless frontmatter_value(protocol_text, "version") == PROTOCOL_VERSION

  REQUIRED_INVARIANTS.each do |invariant|
    errors << "missing invariant #{invariant}" unless protocol_text.include?(invariant)
  end

  supporting_paths = [skill_path] + Dir.glob(File.join(repo, "references", "*.md")).reject { |path| path == protocol_path }
  supporting_text = supporting_paths.select { |path| File.file?(path) }.map { |path| File.read(path) }.join("\n")
  REQUIRED_PACKET_MARKERS.each do |marker|
    errors << "missing task-packet ownership marker #{marker}" unless supporting_text.include?(marker)
  end

  {
    skill: skill_name,
    protocol_version: frontmatter_value(protocol_text, "version"),
    protocol_sha256: sha256(protocol_path),
    checker_sha256: File.file?(checker_path) ? sha256(checker_path) : nil,
    errors: errors
  }
end

local_repo = File.expand_path("..", __dir__)
results = [validate_repo(local_repo)]
errors = results.first[:errors].map { |error| "#{results.first[:skill]}: #{error}" }

if options[:siblings_root]
  expected_protocol_sha = results.first[:protocol_sha256]
  expected_checker_sha = results.first[:checker_sha256]

  SUPPORTED_SKILLS.each do |skill_name|
    repo = File.join(options[:siblings_root], skill_name)
    unless File.directory?(repo)
      errors << "#{skill_name}: missing sibling repository" if options[:require_all]
      next
    end

    result = repo == local_repo ? results.first : validate_repo(repo)
    results << result unless repo == local_repo
    result[:errors].each { |error| errors << "#{skill_name}: #{error}" }
    if result[:protocol_sha256] && result[:protocol_sha256] != expected_protocol_sha
      errors << "#{skill_name}: protocol content differs from local copy"
    end
    if result[:checker_sha256] && result[:checker_sha256] != expected_checker_sha
      errors << "#{skill_name}: alignment checker differs from local copy"
    end
  end
end

payload = {
  ok: errors.empty?,
  protocol: "#{PROTOCOL_ID}@#{PROTOCOL_VERSION}",
  local_skill: File.basename(local_repo),
  checked_skills: results.map { |result| result[:skill] }.uniq.sort,
  protocol_sha256: results.first[:protocol_sha256],
  checker_sha256: results.first[:checker_sha256],
  errors: errors.uniq
}

puts JSON.pretty_generate(payload)
exit(errors.empty? ? 0 : 1)
