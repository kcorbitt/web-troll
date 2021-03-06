class Book < ActiveRecord::Base
  has_many :isbns, dependent: :destroy
  accepts_nested_attributes_for :isbns

  belongs_to :user

  attr_accessor :error

  include CalculationStatus
  include Errors

  def to_hash
    hash = {}
    hash[:author]             = self.author
    hash[:title]              = self.title
    hash[:url]                = self.url
    hash[:author_url]         = self.author_url
    hash[:reading_level]      = self.reading_level
    hash[:calculation_status] = self.calculation_status
    hash[:isbn]               = self.isbn
    hash[:id]                 = self.id
    hash
  end

  def self.from_isbn isbn
    # if not /^(\d{10}|\d{13})$/ =~ isbn
    #   @book = Book.new
    #   @book.calculation_status = 3
    #   @book.error = Errors::BAD_FORMAT
    # else
      cached = Isbn.find_by_number isbn
      if cached
        @book = cached.respond_to?(:first) ? cached.first.book : cached.book
      else
        client = Openlibrary::Client.new
        book_data = client.search isbn: isbn
        if book_data[0]
          @book = from_openlibrary(book_data[0])
        else
          @book = Book.new
          @book.calculation_status = 3
          @book.error = Errors::NOT_FOUND
        end
      end
    # end
    @book
  end

  def self.from_openlibrary book_obj
    book = self.new
    book.title          = book_obj.title
    book.author         = book_obj.author_name[0] if book_obj.author_name
    book.author_url     = "http://openlibrary.org/authors/#{book_obj.author_key[0]}" if book_obj.author_key
    book.url            = "http://openlibrary.org/works/#{book_obj.key!}"

    temp_isbns = []
    book_obj.isbn.each do |x|
      if x =~ /\A(978[01].{6}|[01].{9})/
        temp_isbns << x
      end
    end

    if temp_isbns.size == 0
      return nil
    end

    require 'net/http'
    require 'rexml/document'

    url = 'http://www.librarything.com/api/thingISBN/'.concat(temp_isbns[0])
    xml_data = Net::HTTP.get_response(URI.parse(url)).body
    doc = REXML::Document.new(xml_data)
    doc.elements.each('idlist/isbn') do |isbn|
      if isbn.text =~ /\A(978[01].{6}|[01].{9})/
        temp_isbns << isbn.text
        Rails.logger.debug(isbn.text)
      end
    end

    temp_isbns.uniq.each do |x|
      book.add_isbn x
    end
    book
  end

  def calculate_reading_level user=nil
    if self.calculation_status.nil?
      update_attributes calculation_status: CalculationStatus::IN_PROGRESS, user: user
      Resque.enqueue CalculateLevel, id
    elsif self.calculation_status == Book::CalculationStatus::IN_PROGRESS && Time.now-self.updated_at > 20.minutes
      Resque.enqueue CalculateLevel, id
    end
  end

  def reading_hash
    if self.calculation_status == 3
      {
        calculation_status: 3,
        error: @error ? @error : Errors::NO_DATA
      }
    else
      {
        calculation_status: self.calculation_status,
        reading_level: reading_level ? reading_level.to_f : nil
      }
    end
  end

  def isbn
    @isbn ||= isbns.first.number if isbns
  end

  def add_isbn (number)
    isbns.new(number: number)
  end
  alias_method :isbn=, :add_isbn

end
