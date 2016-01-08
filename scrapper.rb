require 'mysql'
require 'io/console'
require 'open-uri'
# nokogiri is an HTML, XML, SAX and Reader parser
# nokogiri has a ability to serch document via XPath and css3 selectors
require 'nokogiri'

DB_URL = "localhost"
DB_USER_NAME = "root"
DB_PASSWORD = "redhat"
DB_NAME = "scrap"


class Scrapper
	public
	def getCategoryNames(baseURL)
		html = open(baseURL)
		document = Nokogiri::HTML(html)
		categoryNames = document.css('section ul li ul li a').map(&:text)
		# the drop down list on website contains some other links which are not real categories so they removed
		categoryNames.shift
		7.times do
			categoryNames.pop
		end
		# array of category is returned
		categoryNames
	end

	public
	def getCategoryURLs(htmlDocument)
		categoryURLs = htmlDocument.css('section ul li ul li a').map{ |link| link['href'] }
		categoryURLs.shift
		7.times do
			categoryURLs.pop
		end
		categoryURLs
	end

	public
	def saveCategoryNames(connection, categoryNames)
		rs = connection.query "select count(*) from category"
		if (rs.fetch_row[0] <=> "0") == 0
			categoryNames.each do |category|
				connection.query "insert into category(name) values('#{category}')"
			end
		end
	end

	public
	def getCategoryIDs(connection)
		rs = connection.query "select ID from category"
		categoryIDs = Array.new
		rs.each do |row|
			categoryIDs << row[0]
		end
		categoryIDs
	end

	public
	def saveRecipe(connection, name, categoryName, description, servings, preptime, total_time)
		# puts "\n\n"
		# puts "Recipe Name: #{name}"
		# puts "Category: #{categoryName}"
		# puts "Description: #{description}"
		# puts "Servings: #{servings}"
		# puts "Prep Time: #{preptime}"
		# puts "Total Time: #{total_time}"
		# puts "insert into recipe(name, category_id, description, servings, prep_time, total_time) values ('#{name}', (select category.id from category where name = '#{categoryName}'), '#{description}', '#{servings}', '#{preptime}', '#{total_time}')"
		# puts "\n\n"
		# puts "select count(*) from recipe where name='#{name}'"
		puts "Recipe saved"
		rs = connection.query "select count(*) from recipe where name='#{name}'"
		if(rs.fetch_row[0] <=> "0")
			connection.query "insert into recipe(name, category_id, description, servings, prep_time, total_time) values ('#{name}', (select category.id from category where name = '#{categoryName}'), '#{description}', '#{servings}', '#{preptime}', '#{total_time}')"
			# puts "inside"
		end
	end

	public
	def saveIngredients(connection, name, recipeID)
		connection.query "insert into ingredients(name, receipe_id) values('#{name[0]}', #{recipeID});"
		# puts "insert into ingredients(name, receipe_id) values('#{name[0]}', #{recipeID});"
		puts "Ingredients saved"
	end

	public
	def saveDirections(connection, name, recipeID)
		connection.query "insert into directions(name, receipe_id) values('#{name[0]}', #{recipeID});"
		# puts "insert into directions(name, receipe_id) values('#{name[0]}', #{recipeID});"
		puts "Directions saved"
	end

	public
	def getRecipeID(connection, recipeName)
		# puts "select id from recipe where name='#{recipeName}'"
		rs = connection.query "select id from recipe where name='#{recipeName}'"
		# puts "Row:#{rs.fetch_row[0]}"
		# puts rs.size
		rs.fetch_row[0]
	end

	public
	def checkRecipe(connection, recipeName)
		rs = connection.query "select count(*) from recipe where name = '#{recipeName}'"
		rs.fetch_row[0]
	end
end



begin
	scrapper = Scrapper.new
	system "clear"
    connection = Mysql.new DB_URL, DB_USER_NAME, DB_PASSWORD
    puts "-------------Successfylly connected to MySQL-------------"
    puts "Mysql Version:"+connection.get_server_info
	connection.query "create database IF NOT EXISTS #{DB_NAME}"
	connection = Mysql.new DB_URL, DB_USER_NAME, DB_PASSWORD, DB_NAME
    connection.query "create table IF NOT EXISTS category(ID int primary key auto_increment, name varchar(50))"
    connection.query "create table IF NOT EXISTS recipe(id int primary key auto_increment, name varchar(50), category_id int not null, description varchar(200), servings varchar(10), prep_time varchar(20), total_time varchar(20), constraint foreign key(category_id) references category(ID) on delete cascade on update cascade);"
    connection.query "create table IF NOT EXISTS ingredients(id int primary key auto_increment, name varchar(100), receipe_id int not null, constraint foreign key(receipe_id) references recipe(id) on delete cascade on update cascade)"
    connection.query "create table IF NOT EXISTS directions(id int primary key auto_increment, name varchar(250), receipe_id int not null, constraint foreign key(receipe_id) references recipe(id) on delete cascade on update cascade)"
    puts "\n-------------Database successfully Initialized-------------"
    baseURL = "http://www.recipe.com"
    # saving category names in database
    scrapper.saveCategoryNames(connection, scrapper.getCategoryNames(baseURL))
    # fetching category ID's from database for relation mapping
    categoryIDs = scrapper.getCategoryIDs(connection)
    # categoryIDs.each do|categoryID|
    # 	puts categoryID
    # end
	baseHtml = open(baseURL)
	htmlDocument = Nokogiri::HTML(baseHtml)
	categoryURLs = scrapper.getCategoryURLs(htmlDocument)
	categoryURLs.each do |categoryURL|
		# puts categoryURL
		categoryHtml = open(categoryURL)
		categoryHtmlDocument = Nokogiri::HTML(categoryHtml)
		reciepeURLS = categoryHtmlDocument.css('h3 a').map{ |link| link['href'] }
		reciepeURLS.each do |reciepeURL|
			# puts reciepeURL
			reciepeHtml = open(reciepeURL)
			reciepeHtmlDocument = Nokogiri::HTML(reciepeHtml)
			recipeName = ""
			recipeDescription = ""
			reciepeHtmlDocument.css('#topColumn1').each do |recipeDetails|
				# puts reciepeURL
				recipeName = recipeDetails.css('h1').map(&:text)[0]
				recipeDescription = recipeDetails.css('p').map(&:text)[0]
			end
			serving = ""
			reciepeHtmlDocument.css('div#recipePrepAndServe').each do |recipeDetails|
				recipeServings = recipeDetails.css('div .yield').map(&:text)
				if recipeServings.size != 0
					serving = recipeServings[0].strip
				end
				# puts serving.size
				# puts "Servings: #{serving}"
				# puts "out"
			end
			preptime = ""
			reciepeHtmlDocument.css('#recipePrepAndServe').each do |recipeDetails|
				recipePrepTime = recipeDetails.css('div .preptime').map(&:text)
				if recipePrepTime.size != 0
					preptime = recipePrepTime[0].strip
				end
				# puts "Prep Time: #{preptime}"
				# puts "out"
			end
			total_time = ""
			reciepeHtmlDocument.css('#recipePrepAndServe').each do |recipeDetails|
				recipetotal_time = recipeDetails.css('div .duration').map(&:text)
				if recipetotal_time.size != 0
					total_time = recipetotal_time[0].strip
				end
				# puts "in total_time"
				# puts "Total Time: #{total_time}"
				# puts "out"
			end

			if recipeName.size != 0
				if scrapper.checkRecipe(connection, recipeName) <=> "0"
					recipeName = recipeName.gsub("-","")
					recipeName = recipeName.gsub("'","")
					recipeDescription = recipeDescription.gsub("-","")
					recipeDescription = recipeDescription.gsub("'","")
					scrapper.saveRecipe(connection, recipeName, categoryURL.split("/").last, recipeDescription, serving, preptime, total_time)
					recipeID = scrapper.getRecipeID(connection, recipeName)
					# puts recipeID

					ingredient = ""
					reciepeHtmlDocument.css('.gs_ingredient').each do |recipeDetails|
						ingredient = recipeDetails.css('div div').map(&:text)[0] 
						ingredient = ingredient.strip
						ingredient = ingredient.gsub("'","")
						ingredient = ingredient.split(/\n/)
						scrapper.saveIngredients(connection, ingredient[0], recipeID)
						# puts ingredient
					end

					directions = ""
					reciepeHtmlDocument.css('.step').each do |recipeDetails|
						directions = recipeDetails.css('div').map(&:text)[1]
						directions = directions.strip
						directions = directions.gsub("'","")
						directions = directions.split(/\n/)
						scrapper.saveDirections(connection, directions, recipeID)
						# puts directions
					end
				end
			end

		end
		# puts categoryURL.split("/").last
		# puts "out"
	end




    
rescue Mysql::Error => e
	puts "\n\n"
	puts "-------------Failed to connect with MySQL-------------"
    puts "Error No: #{e.errno}"
    puts "Message: #{e.error}"
    puts "\nPossible cause,"
    puts "1. User name and password should not be blank."
    puts "2. Check user name and password of the database."
    puts "3. Mysql database may not be properly installed. Try re-installing."
    puts "4. Are trying to break things...:-)."
rescue LoadError
    
ensure
    connection.close if connection
end