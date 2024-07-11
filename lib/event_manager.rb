require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone(phone_number)
  phone_number.gsub!(/[^\d]/, "")
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == "1"
    phone_number[1..10]
  else
    ""
  end
end


def registrations_per_hour(file, column_name)
  registrations = []
  CSV.foreach(file, headers: true, header_converters: :symbol) do |row|
    time = row[column_name].split(" ")[1]
    time_obj = DateTime.parse(time, "%H:%M")
    registrations << time_obj.hour
  end
  return registrations
end

def registrations_per_wday(file, column_name)
  registrations = []
  CSV.foreach(file, headers:true, header_converters: :symbol) do |row|
    date = row[column_name].split(" ")[0]
    begin
      date_obj = Date.parse(date)
    rescue Date::Error
      date_obj = Date.strptime(date, "%m/%d/%y")      
    end
    registrations << date_obj.strftime("%A")
  end
  return registrations
end


def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone(row[:homephone])
  registration_date = row[:regdate]
  datetime_obj = DateTime.strptime(registration_date, "%m/%d/%y %H:%M")
  date = datetime_obj.strftime("%d/%m")
  weekday_number = datetime_obj.wday
  weekday_name = datetime_obj.strftime("%A") 
  hour = datetime_obj.hour
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

