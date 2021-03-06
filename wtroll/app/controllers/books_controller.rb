class BooksController < ApplicationController
	respond_to :json, only: :reading_level

	def show
		@results = []
		if /^\s*((\d{10}|\d{13})\s+)*(\d{10}|\d{13})?\s*$/ =~ params[:query]
			search_isbns
		else
			search_books
		end
	end

	def search_isbns
		params[:query].split.each do |isbn|
			@results << Book.from_isbn(isbn)
		end
	end

	def search_books
		searcher = Openlibrary::Client.new

		raw_results = searcher.search(params[:query], 20)
		raw_results.select{ |result| result.isbn }.each do |result|
			cached = Isbn.find_by_number(result.isbn.first)
			if not cached.nil?
				@results << cached.book
			else
				temp = Book.from_openlibrary(result)
				if temp != nil
					@results << Book.from_openlibrary(result)
				end
			end
		end
	end

	def reading_level
		@book = Book.find(params[:book_id])
		@book.calculate_reading_level
	end

	def create
		@book = Book.from_isbn new_book_params[:isbn]
		@book.save
		render status: :created
	end
private
	def new_book_params
		# should be .require :isbn, but apparently .require with this format
		# is not currently supported.
		# github.com/rails/strong_parameters/issues/139
		params.permit(:isbn, :title, :url, :author, :author_url)
	end

end	
