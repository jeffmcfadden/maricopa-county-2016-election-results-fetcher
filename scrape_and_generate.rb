require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'json'

html = Nokogiri::HTML( open( 'http://recorder.maricopa.gov/electionresults/eresults_noscroll.aspx' ) )

date_string = html.css( '#lblUpdate' ).text.split( 'Last update:' )[1].strip

last_updated_month  = date_string.split( '/' )[0].to_i
last_updated_day    = date_string.split( '/' )[1].to_i
last_updated_year   = date_string.split( '/' )[2].split( ' ' )[0].to_i
last_updated_hour   = date_string.split( ' ' )[1].split( ':' )[0].to_i
last_updated_hour   += 12 if date_string.split( ' ' )[2] == 'PM'
last_updated_minute = date_string.split( ' ' )[1].split( ':' )[1].to_i
last_updated_second = date_string.split( ' ' )[1].split( ':' )[2].to_i

last_updated = Time.new( last_updated_year, last_updated_month, last_updated_day, last_updated_hour, last_updated_minute, last_updated_second, '-07:00')

def file_name_for_race( race )
  race.downcase.gsub(' ', '-').gsub( '(', '' ).gsub( ')', '' ).gsub( '#', '-' )
end

def text_for_race_data( race_data )
  text = "#{race_data[:race]}" + "\n"
  text += "-" * 45 + "\n"
  
  race_data[:candidates].each do |c|
    text += c[:name][0..21].ljust( 23 ) + " | " + c[:vote_share].to_f.round(1).to_s.rjust( 5 ) + "% | " + c[:total_votes].to_s.rjust( 9 ) + "\n"
  end
  
  text += "\n"
end

results_data = {}
this_race  = nil
html.css( '#tblElectionResults' ).css( 'tr' ).each do |row|
  race_title = row.css( 'td' ).first.text.to_s.strip
  
  if race_title != '' && race_title.length > 4
    # puts "Race row (#{race_title})" 
    if this_race != nil
      results_data[this_race[:race]] = this_race
    end
    this_race  = { race: race_title, candidates: [] }
  else
    # puts "Candidate row"
    
    candidate_name = row.css( 'td' )[2].text.to_s.gsub( 'NON - ', '' )
    candidate_early_votes = row.css( 'td' )[3].text.to_i
    candidate_total_votes = row.css( 'td' )[4].text.to_i
    candidate_share_votes = row.css( 'td' )[5].text.to_f
    
    this_race[:candidates].push( { name: candidate_name, early_votes: candidate_early_votes, total_votes: candidate_total_votes, vote_share: candidate_share_votes } )
  end
end

data = { last_updated: last_updated, results: results_data }

File.open( 'all_results.json', 'w') {|f| f.write(data.to_json) }


all_races_html = ""
all_results_txt = ""
results_data.each do |race_name, data|
  
  candidates_html = ""
  data[:candidates].each do |candidate|
    this_candidate_html = open( './candidate_results_template.html' ).read
    this_candidate_html.gsub!( '<!-- candidate_name -->', candidate[:name] )
    this_candidate_html.gsub!( '<!-- candidate_votes -->', candidate[:total_votes].to_s )
    this_candidate_html.gsub!( '<!-- candidate_vote_share -->', candidate[:vote_share].to_s )
    candidates_html += this_candidate_html + "\n"
  end
  
  this_race_html       = open( 'individual_result_template.html' ).read
  this_race_html.gsub!( '<!-- race_name -->', race_name )
  this_race_html.gsub!( '<!-- race_link_html -->', "results/#{file_name_for_race(race_name)}.html" )
  this_race_html.gsub!( '<!-- race_link_json -->', "results/#{file_name_for_race(race_name)}.json" )
  this_race_html.gsub!( '<!-- race_link_txt -->',  "results/#{file_name_for_race(race_name)}.txt" )
  this_race_html.gsub!( '<!-- candidate_values -->', candidates_html )
  
  all_races_html += this_race_html + "\n"
  
  this_race_individual_html = open( 'individual_result_page_template.html' ).read
  this_race_individual_html.gsub!( '<!-- race_name -->', race_name )
  this_race_individual_html.gsub!( '<!-- results -->', this_race_html )
  this_race_individual_html.gsub!( '<!-- last_update -->', last_updated.strftime("%a, %b %-d, %-l:%M%P") )
  
  File.open( "results/#{file_name_for_race(race_name)}.html", 'w') {|f| f.write( this_race_individual_html ) }
  
  this_race_txt = text_for_race_data( data )
  all_results_txt += this_race_txt
  
  File.open( "results/#{file_name_for_race(race_name)}.txt", 'w') {|f| f.write(this_race_txt) }  
  
  json_data = { last_updated: last_updated, results: data }
  File.open( "results/#{file_name_for_race(race_name)}.json", 'w') {|f| f.write(json_data.to_json) }
end

all_results_html = open( 'all_results_template.html' ).read
all_results_html.gsub!( '<!-- all_results -->', all_races_html )
all_results_html.gsub!( '<!-- last_update -->', last_updated.strftime("%a, %b %-d, %-l:%M%P") )

File.open( './index.html', 'w') {|f| f.write( all_results_html ) }

File.open( './all_results.txt', 'w') {|f| f.write( all_results_txt ) }