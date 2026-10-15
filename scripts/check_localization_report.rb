#!/usr/bin/env ruby
require "set"

root = File.expand_path("..", __dir__)
locales = %w[vi en]
source_root = File.join(root, "FamilyTracker")
allowlist_path = File.join(root, "scripts/localization-allowlist.txt")

def strings_entries(path)
  entries = []
  File.foreach(path).with_index(1) do |line, line_number|
    match = line.match(/^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;/)
    entries << [match[1], match[2], line_number] if match
  end
  entries
end

def allowed?(record, allowlist)
  allowlist.any? { |pattern, _reason| pattern.match?(record) }
end

allowlist = File.readlines(allowlist_path, chomp: true).filter_map do |line|
  next if line.empty? || line.start_with?("#")

  pattern, reason = line.split("|", 2)
  [Regexp.new(pattern), reason]
rescue RegexpError => error
  warn "Invalid localization allowlist pattern: #{error.message}"
  nil
end

tables = locales.to_h do |locale|
  path = File.join(source_root, "Resources", "#{locale}.lproj", "Localizable.strings")
  [locale, strings_entries(path)]
end
keys = locales.to_h { |locale| [locale, tables.fetch(locale).map(&:first)] }
key_sets = keys.transform_values(&:to_set)

missing_by_locale = {
  "vi" => key_sets.fetch("en") - key_sets.fetch("vi"),
  "en" => key_sets.fetch("vi") - key_sets.fetch("en")
}
empty_values = tables.flat_map do |locale, entries|
  entries.filter_map { |key, value, line| "#{locale}.lproj/Localizable.strings:#{line}: #{key}" if value.empty? }
end
duplicates = tables.flat_map do |locale, entries|
  entries.group_by(&:first).filter_map do |key, values|
    "#{locale}.lproj/Localizable.strings: #{key.inspect} (#{values.map { |entry| entry[2] }.join(', ')})" if values.length > 1
  end
end

used_keys = []
literal_findings = []
api_bypasses = []
plural_candidates = 0
ui_literal = /(?:\bText|\bButton|\bLabel|\bSection|\bPicker|\bMenu|\bTextField|\bSecureField|\bnavigationTitle|\bnavigationSubtitle|\bconfirmationDialog|\baccessibilityLabel|\baccessibilityHint|\baccessibilityValue)\s*\(\s*"((?:\\.|[^"\\])*)"/
localized_call = /(?:L10n\.(?:tr|text|format|message)\s*\(\s*|AppLocalizedText\s*\(\s*)"((?:\\.|[^"\\])*)"/m

swift_files = Dir.glob(File.join(source_root, "**/*.swift")).sort
swift_files.each do |path|
  relative = path.delete_prefix("#{root}/")
  content = File.read(path)
  content.to_enum(:scan, localized_call).each do
    match = Regexp.last_match
    line_number = content[0...match.begin(0)].count("\n") + 1
    used_keys << [relative, line_number, match[1]]
  end
  content.each_line.with_index(1) do |line, line_number|
    next if line.lstrip.start_with?("//")

    if (match = line.match(ui_literal))
      record = "#{relative}:#{line_number}:#{line.strip}"
      literal_findings << record unless allowed?(record, allowlist)
    end
    if line.match?(/\bNSLocalizedString\s*\(|String\s*\(\s*localized\s*:/)
      api_bypasses << "#{relative}:#{line_number}:#{line.strip}"
    end
    plural_candidates += line.scan(/\b(?:count|Count|memberCount|unreadCount|onlineMembersCount)\b/).length
  end
end

known_keys = key_sets.values.reduce(&:|)
missing_usage = used_keys.reject { |_path, _line, key| known_keys.include?(key) }
formatted_entries = tables.fetch("vi").count { |key, _value, _line| key.match?(/%(?:\d+\$)?(?:lld|ld|d)/) }
format_pattern = /%(?:\d+\$)?(?:lld|ld|d|@)/
translations = locales.to_h do |locale|
  [locale, tables.fetch(locale).to_h { |key, value, _line| [key, value] }]
end
format_mismatches = (key_sets.fetch("vi") & key_sets.fetch("en")).filter_map do |key|
  vi_placeholders = translations.fetch("vi").fetch(key).scan(format_pattern).sort
  en_placeholders = translations.fetch("en").fetch(key).scan(format_pattern).sort
  "#{key.inspect}: vi=#{vi_placeholders.inspect}, en=#{en_placeholders.inspect}" unless vi_placeholders == en_placeholders
end

puts "Localization static report (CI-enforced)"
puts "Swift files scanned: #{swift_files.length}"
puts "Resource keys: vi=#{key_sets.fetch('vi').length}, en=#{key_sets.fetch('en').length}"
puts "New namespaced keys: #{(key_sets.fetch('vi') | key_sets.fetch('en')).count { |key| key.match?(/\A[a-zA-Z]+\.[a-zA-Z0-9_.]+\z/) }}"
puts "Hard-coded UI/accessibility literal candidates: #{literal_findings.length} (#{allowlist.length} allowlist rules)"
puts "Localization-helper literal references: #{used_keys.length}; references missing from both resource tables: #{missing_usage.length}"
puts "Resource parity differences: vi missing #{missing_by_locale.fetch('vi').length}, en missing #{missing_by_locale.fetch('en').length}"
puts "Empty translations: #{empty_values.length}; duplicate keys: #{duplicates.length}"
puts "Direct NSLocalizedString/String(localized:) bypasses: #{api_bypasses.length}"
puts "Format templates with integer placeholders (plural review candidates): #{formatted_entries}; count-related source identifiers: #{plural_candidates}"
puts ".stringsdict resources: #{Dir.glob(File.join(source_root, "Resources/**/*.stringsdict")).length}; plural forms require manual validation"

{ "Missing keys used in Swift" => missing_usage.map { |path, line, key| "#{path}:#{line}: #{key.inspect}" },
  "Resource parity differences" => missing_by_locale.flat_map { |locale, values| values.map { |key| "#{locale} missing #{key.inspect}" } },
  "Empty translations" => empty_values,
  "Duplicate keys" => duplicates,
  "SwiftUI literal candidates (first 35)" => literal_findings.first(35),
  "Direct API bypasses" => api_bypasses,
  "Translation format mismatches" => format_mismatches }.each do |heading, findings|
  next if findings.empty?

  puts "\n#{heading}:"
  findings.each { |finding| puts "  #{finding}" }
  remaining = heading.include?("first 35") ? literal_findings.length - findings.length : 0
  puts "  ... #{remaining} additional matches omitted" if remaining.positive?
end

violations = missing_usage.length + missing_by_locale.values.sum(&:length) + empty_values.length + duplicates.length +
             literal_findings.length + api_bypasses.length + format_mismatches.length
abort("Localization source/resource checks failed with #{violations} finding(s).") if violations.positive?
