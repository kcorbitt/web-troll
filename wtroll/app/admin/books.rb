ActiveAdmin.register Book do
	menu priority: 1

	collection_action :calculate_batch
	collection_action :process_calculate_batch, method: :post
	collection_action :clear_errored_books, method: :post
	action_item only: :index do
		link_to "Calculate Batch", calculate_batch_admin_books_path
	end
	action_item only: :index do
		link_to "Clear Errored Books", clear_errored_books_admin_books_path, method: :post
	end

	index do
		selectable_column
		column :title
		column :author
		column :reading_level
		column "ISBNs" do |book|
			book.isbns.limit(10).map &:number
		end
		column "Calculation Status" do |book|
			case book.calculation_status
			when nil 	then ""
			when 1 		then "In Progress"
			when 2		then "Success"
			when 3 		then "Error"
			end
		end
		column "API requester", :user
		default_actions
	end

	show title: :title do |book|
		attributes_table do
			row :id
			row :title
			row :author
			row :url
			row :author_url
			row :user
			table_for book.isbns do
				column "ISBNs" do |isbn|
					isbn.number
				end
			end
		end
	end
	csv do
		column :id
		column :title
		column :author
		column("isbns") { |book| book.isbns.map{|x| x.number}.join("|") }
		column :reading_level
		column :created_at
		column :updated_at
		column :calculation_status
	end
	controller do
		def calculate_batch
			render 'calculate_batch'
		end
		def process_calculate_batch
			params[:isbns].split(/,|\s/).select{|x| x.match(/\d/)}.each do |isbn|
				book = Book.from_isbn(isbn)
				book.calculate_reading_level
			end

			flash[:notice] = "Calculating reading levels.  This may take a while."
			redirect_to action: :index
		end
		def clear_errored_books
			Book.destroy_all(calculation_status: 3)
			flash[:notice] = "All books with errors dropped from database"
			redirect_to action: :index
		end
	end
end
