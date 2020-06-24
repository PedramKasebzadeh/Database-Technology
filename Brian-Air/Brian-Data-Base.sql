/*###########################################*/
/*1. Initialization */
/*###########################################*/
-- use pedka102;
DROP TABLE IF EXISTS babooking;
DROP TABLE IF EXISTS bacontact;
DROP TABLE IF EXISTS bapassenger;
DROP TABLE IF EXISTS bareservationpassengers;
DROP TABLE IF EXISTS baperson;
DROP TABLE IF EXISTS bacreditcard;
DROP TABLE IF EXISTS bareservation;
DROP TABLE IF EXISTS baflight;
DROP TABLE IF EXISTS barouteprice;
DROP TABLE IF EXISTS baschedule;
DROP TABLE IF EXISTS baroute;
DROP TABLE IF EXISTS baairport;
DROP TABLE IF EXISTS bawdfactors;
DROP TABLE IF EXISTS bapfactors;

DROP PROCEDURE IF EXISTS addYear;
DROP PROCEDURE IF EXISTS addDay;
DROP PROCEDURE IF EXISTS addDestination;
DROP PROCEDURE IF EXISTS addRoute;
DROP PROCEDURE IF EXISTS addFlight;

DROP FUNCTION IF EXISTS calculateFreeSeats;
DROP FUNCTION IF EXISTS calculatePrice;

DROP PROCEDURE IF EXISTS addReservation;
DROP PROCEDURE IF EXISTS addPassenger;
DROP PROCEDURE IF EXISTS addContact;
DROP PROCEDURE IF EXISTS addPayment;

DROP VIEW IF EXISTS allFlights;


/*###########################################*/
/*2. Creating Tables */
/*###########################################*/

CREATE TABLE bapfactors(
    year INTEGER PRIMARY KEY,
    profitfactor DOUBLE DEFAULT 0
);

CREATE TABLE bawdfactors(
    year INTEGER,
    day VARCHAR(10),
    weekdayfactor DOUBLE DEFAULT 1, 
    PRIMARY KEY (year, day)
);


CREATE TABLE baairport(
    id VARCHAR(3) PRIMARY KEY,
    name VARCHAR(30),
    country VARCHAR(30)
);


CREATE TABLE baroute(
    deptairport VARCHAR(3),
    arrivairport VARCHAR(3),
    PRIMARY KEY (deptairport, arrivairport),
    constraint fk_route_airpdep FOREIGN KEY (deptairport) REFERENCES baairport (id),
	constraint fk_route_airparr FOREIGN KEY (arrivairport) REFERENCES baairport (id)
);

CREATE TABLE barouteprice(
    deptairport VARCHAR(3),
    arrivairport VARCHAR(3),
    year INTEGER,
    price DOUBLE,
    PRIMARY KEY(deptairport, arrivairport, year), 
	constraint fk_routeprice_route FOREIGN KEY (deptairport, arrivairport) REFERENCES baroute (deptairport, arrivairport)
);


CREATE TABLE baschedule(
	id INTEGER PRIMARY KEY NOT NULL AUTO_INCREMENT,
	deptairport VARCHAR(3),
    arrivairport VARCHAR(3),
    departuretime TIME,
    day VARCHAR(10),
	year INTEGER,
    constraint fk_schedule_route FOREIGN KEY (deptairport, arrivairport) REFERENCES baroute (deptairport, arrivairport),
    constraint fk_schedule_pfactors FOREIGN KEY (year) REFERENCES bapfactors(year),
    constraint fk_schedule_wdfactors  FOREIGN KEY (year,day) REFERENCES bawdfactors(year,day)
);

CREATE TABLE baflight(
    id INTEGER PRIMARY KEY NOT NULL AUTO_INCREMENT,
    week INTEGER,
    schedule INTEGER,
    constraint fk_flight_schedule FOREIGN KEY (schedule) REFERENCES baschedule (id)
);

CREATE TABLE bareservation(
    id INTEGER PRIMARY KEY NOT NULL AUTO_INCREMENT,
    price DOUBLE,
    noofpassengers INTEGER,
    flight INTEGER,
    constraint fk_reservation_flight FOREIGN KEY (flight) REFERENCES baflight (id)
);

CREATE TABLE bacreditcard(
    number BIGINT PRIMARY KEY,
    holder VARCHAR(30)
);


CREATE TABLE baperson(
    passportno INTEGER PRIMARY KEY,
    name VARCHAR(30)
);

CREATE TABLE bapassenger(
    ticketno INTEGER PRIMARY KEY NOT NULL AUTO_INCREMENT,
    booking INTEGER,
    passportno INTEGER,
    constraint fk_passenger_person FOREIGN KEY (passportno) REFERENCES baperson (passportno)
);

CREATE TABLE bacontact(
    passportno INTEGER,
    reservation INTEGER,
    email VARCHAR(30),
    phoneno BIGINT,
    PRIMARY KEY (passportno, reservation),
    constraint fk_contact_passenger FOREIGN KEY (passportno) REFERENCES baperson (passportno)
);

CREATE TABLE bareservationpassengers(
    id INTEGER,
    passportno INTEGER,
    PRIMARY KEY (id, passportno),
    constraint fk_reservationpassengers_person FOREIGN KEY (passportno) REFERENCES baperson (passportno), 
    constraint fk_reservationpassengers_reservation FOREIGN KEY (id) REFERENCES bareservation (id)
);

CREATE TABLE babooking(
    id INTEGER PRIMARY KEY,
    creditcard BIGINT,
    passportno INTEGER,
    constraint fk_booking_creditcard FOREIGN KEY (creditcard) REFERENCES bacreditcard (number), 
    constraint fk_booking_contact FOREIGN KEY (passportno) REFERENCES bacontact (passportno)
);

/*###########################################*/
/*3. Creating Procedures Part1 */
/*###########################################*/

DELIMITER $$
CREATE PROCEDURE addYear (IN year INTEGER, IN factor DOUBLE)
BEGIN
	INSERT INTO bapfactors (year, profitfactor) 
    VALUES (year, factor);
END$$

DELIMITER $$
CREATE PROCEDURE addDay (IN year INTEGER, IN day VARCHAR(10), IN factor DOUBLE)
BEGIN
	INSERT INTO bawdfactors (year, day, weekdayfactor) 
    VALUES (year, day, factor);
END$$


DELIMITER $$
CREATE PROCEDURE addDestination (IN airport_code VARCHAR(3), IN name VARCHAR(30), IN country VARCHAR(30))
BEGIN
	INSERT INTO baairport (id, name, country) 
    VALUES (airport_code, name, country);
END$$


DELIMITER $$
CREATE PROCEDURE addRoute (IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(3), IN year INTEGER, IN routeprice DOUBLE)
BEGIN
	DECLARE my_id INTEGER;

	/*Add information to baroute*/
	IF (SELECT COUNT(*) FROM baroute WHERE deptairport = departure_airport_code AND arrivairport = arrival_airport_code) = 0 THEN
		INSERT INTO baroute (deptairport, arrivairport) 
		VALUES (departure_airport_code, arrival_airport_code);
	END IF;
    
	/*Add information to barouteprice*/
	INSERT INTO barouteprice (deptairport, arrivairport, year, price)
	VALUES (departure_airport_code, arrival_airport_code, year, routeprice);
    
END$$



DELIMITER $$
CREATE PROCEDURE addFlight (IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(3), IN year INTEGER, IN day VARCHAR(10), IN departure_time TIME)
BEGIN
	
    DECLARE schedule_id INTEGER;
    DECLARE week int default 1;
    DECLARE week_max int default 52;

	/*Add information to baschedule*/
	INSERT INTO baschedule (deptairport, arrivairport, departuretime, day, year) 
    VALUES (departure_airport_code, arrival_airport_code, departure_time, day, year);
    
	/*Add information to baflight*/
	SET schedule_id = (SELECT max(id) FROM baschedule 
				 WHERE deptairport = deptairport 
					   AND arrivairport = arrivairport
					   AND year = year
                       AND day = day
                       AND departure_time = departure_time);
					
	WHILE week <= week_max do
		INSERT INTO baflight (week, schedule)
		VALUES (week, schedule_id);
        SET week = week + 1;
    END WHILE;
    
END$$


/*###########################################*/
/*4. Creating Help Functions */
/*###########################################*/


delimiter $$
CREATE FUNCTION calculateFreeSeats(flightnumber INTEGER) RETURNS INTEGER

BEGIN
	
DECLARE booked_seats INT(2);
SET booked_seats = (SELECT COUNT(DISTINCT ticketno) 
				  FROM bapassenger
				  WHERE booking in (SELECT babooking.id FROM bareservation
									JOIN babooking ON bareservation.id = babooking.id
                                    WHERE bareservation.flight = flightnumber));
RETURN 40 - booked_seats;
END$$


DROP FUNCTION IF EXISTS calculatePrice;

delimiter $$
CREATE FUNCTION calculatePrice(flightnumber INTEGER) RETURNS DOUBLE

BEGIN
	
DECLARE my_year INTEGER;
DECLARE my_day VARCHAR(30);
DECLARE my_routeprice DOUBLE;
DECLARE my_weekdayfactor DOUBLE;
DECLARE my_profitfactor DOUBLE;
DECLARE my_booked_seats INTEGER;

SET my_year = (SELECT year FROM baschedule 
			   WHERE baschedule.id = (SELECT schedule FROM baflight WHERE baflight.id = flightnumber));
SET my_day = (SELECT day FROM baschedule 
			  WHERE baschedule.id = (SELECT schedule FROM baflight WHERE baflight.id = flightnumber));

SET my_profitfactor = (SELECT profitfactor FROM bapfactors WHERE year = my_year);

SET my_weekdayfactor = (SELECT weekdayfactor FROM bawdfactors WHERE year = my_year and day = my_day);
SET my_routeprice = (SELECT price FROM barouteprice 
				  WHERE year = my_year 
						AND deptairport = (SELECT deptairport FROM baschedule 
											WHERE id = (SELECT schedule FROM baflight 
														WHERE id = flightnumber))
						AND arrivairport = (SELECT arrivairport FROM baschedule 
											WHERE id = (SELECT schedule FROM baflight 
														WHERE id = flightnumber)));
SET my_booked_seats = 40 - calculateFreeSeats(flightnumber);
RETURN (my_routeprice * my_weekdayfactor * my_profitfactor * (my_booked_seats + 1) / 40);
END$$

                                    
/*###########################################*/
/*5. Creating Trigger for Ticket Number*/
/*###########################################*/


DROP TRIGGER IF EXISTS get_ticketno;


delimiter $$
CREATE TRIGGER get_ticketno BEFORE INSERT ON bapassenger
FOR EACH ROW
BEGIN
SET NEW.ticketno = CEILING(RAND()*100000000);
END$$

-- SELECT CEILING(RAND()*100000000) Results;


/*###########################################*/
/*6. Creating Procedures Part2 */
/*###########################################*/


DELIMITER $$
CREATE PROCEDURE addReservation (IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(3), 
								IN year INTEGER, IN week INTEGER, IN day VARCHAR(10), IN time TIME, 
                                IN number_of_passengers INTEGER, OUT output_reservation_nr INTEGER)
BEGIN

	DECLARE my_price INTEGER;
    DECLARE my_flight INTEGER;
    DECLARE flight INTEGER;
    
	SELECT baflight.id INTO flight FROM baflight WHERE baflight.week = week AND baflight.schedule IN (
	SELECT baschedule.id FROM baschedule WHERE baschedule.year = year AND baschedule.day = day AND baschedule.departuretime = time AND baschedule.deptairport = departure_airport_code AND baschedule.arrivairport= arrival_airport_code);
		
    IF flight IS NULL THEN
		SELECT 'There exist no flight for the given route, date and time' as 'Message';
	ELSE
         
    
    SET my_flight = (SELECT baflight.id FROM baflight 
					 LEFT JOIN baschedule ON baflight.schedule = baschedule.id
                     WHERE 
						baschedule.year = year 
                        AND baschedule.day = day 
                        AND baschedule.deptairport = departure_airport_code
                        AND baschedule.arrivairport = arrival_airport_code
                        AND baschedule.departuretime = time
                        AND baflight.week = week);
                        
    IF calculateFreeSeats(my_flight) >= number_of_passengers THEN
		
		SET my_price = calculatePrice(my_flight);
		
		/*Add information to bareservation*/
		INSERT INTO bareservation (price, noofpassengers, flight)
		VALUES (my_price, number_of_passengers, my_flight);
		
		/*Define output variable*/
		SET output_reservation_nr = (SELECT MAX(id) FROM bareservation 
									 WHERE 
										price = my_price 
										AND flight = my_flight 
										AND noofpassengers = number_of_passengers);
	ELSE
           SELECT 'There are not enough seats available on the chosen flight' as 'Message';
     
	END IF;
  END IF;
END$$


				
DELIMITER $$
CREATE PROCEDURE addContact (IN reservation_nr INTEGER, IN passport_number INTEGER, IN email VARCHAR(30), IN phone BIGINT)
BEGIN

	IF (SELECT COUNT(*) FROM bareservationpassengers WHERE id = reservation_nr AND passport_number = passportno) = 1 THEN
		 /*Add information to bapassenger*/
	     INSERT INTO bacontact (passportno, reservation, email, phoneno)
	     VALUES (passport_number, reservation_nr, email, phone);
    ELSE 
         /*Print information/warning*/
		 SELECT 'The person is not a passenger of the reservation' as message;
         /*Raising an error if the contact is not a passenger*/
		 /* SIGNAL SQLSTATE '45000'
		 SET MESSAGE_TEXT = 'Contact should be a passenger'; */
	END IF;  

END$$


DELIMITER $$
CREATE PROCEDURE addPassenger (IN reservation_nr INTEGER, IN passport_number INTEGER, IN name VARCHAR(30))
BEGIN


    /*This if is for a warning statement in case of attemt to Adding a passenger to an already payed reservation*/
    IF (SELECT id FROM babooking WHERE babooking.id = reservation_nr) is NULL THEN
     
    IF (SELECT COUNT(id) FROM bareservation WHERE id = reservation_nr) = 1 THEN
 
		/*Add information to baperson*/
		IF (SELECT COUNT(*) FROM baperson WHERE passportno = passport_number) = 0 THEN
			INSERT INTO baperson (passportno, name) 
			VALUES (passport_number, name);
		END IF;
		
		/*Add information to bareservationpassengers*/
		INSERT INTO bareservationpassengers (id, passportno) 
		VALUES (reservation_nr,passport_number);
        
    ELSE 
    
		/*Print information/warning*/
		SELECT 'The given reservation number does not exist' as message;
        
         /*Raising an error (alternative solution)*/
		 /*SIGNAL SQLSTATE '45001'
		 SET MESSAGE_TEXT = 'The given reservation number does not exist';*/
         
	END IF;  
    
    /* ending error statement */
    ELSE 
         SELECT 'The booking has already been payed and no futher passengers can be added' as message;
    
    END IF;
END$$


DELIMITER $$
CREATE PROCEDURE addPayment (IN reservation_nr INTEGER, IN cardholder_name VARCHAR(30), IN credit_card_number BIGINT)
BEGIN
	DECLARE is_creditcard_available INTEGER;
	DECLARE num_seats_needed INTEGER;
    DECLARE my_flight INTEGER;
    DECLARE temp_contact INTEGER;
    DECLARE my_passport_number INTEGER;
    SET @cnt=0;
    
    SET my_flight = (SELECT flight from bareservation where id = reservation_nr);
    SET is_creditcard_available = (SELECT COUNT(number) FROM bacreditcard where number = credit_card_number);
    SET num_seats_needed = (SELECT COUNT(passportno) from  bareservationpassengers where id = reservation_nr);
    
    /* input data validation*/
    
    /*warning for attempt to Making a payment to a reservation with an incorrect reservation number*/
    IF my_flight is NULL Then 
               SELECT 'The given reservation number does not exist' as message;
	ELSE 
	/* error is done*/
    
	/*warning for attempt to Making a payment to a reservation with no contact*/
    SELECT passportno INTO temp_contact FROM bacontact WHERE bacontact.reservation=reservation_nr;
    IF temp_contact is NULL Then 
               SELECT 'The reservation has no contact yet' as message;
	ELSE 
	/* error is done*/
    
	
  
  IF  calculateFreeSeats(my_flight) >= num_seats_needed THEN
	    /*Add information to bacreditcard*/
		IF is_creditcard_available = 0 THEN
			INSERT INTO bacreditcard (number, holder)
			VALUES (credit_card_number, cardholder_name);
		END IF;
     END IF;    
	 
	IF  calculateFreeSeats(my_flight) >= num_seats_needed THEN
		
        SELECT SLEEP(5); -- COMMENT THIS IN FOR 10c and 10d
		/*Add information to babooking*/
		SET my_passport_number = (SELECT passportno FROM bacontact WHERE bacontact.reservation = reservation_nr);
		INSERT INTO babooking (id, creditcard, passportno)
		VALUES (reservation_nr, credit_card_number, my_passport_number);    
	
		/*Add information to bapassenger*/
		INSERT INTO bapassenger(booking,passportno)
		SELECT reservation_nr, bareservationpassengers.passportno 
		FROM  bareservationpassengers 
        WHERE bareservationpassengers.id = reservation_nr;
    
    ELSE
    
		SELECT "There are not enough seats available on the flight anymore, deleting reservation." as message;
		SET SQL_SAFE_UPDATES = 0;
        DELETE FROM bareservationpassengers WHERE id=reservation_nr; 
        DELETE FROM bareservation WHERE id=reservation_nr;
        DELETE FROM bacontact WHERE reservation=reservation_nr;
        SELECT "There are not enough seats available on the flight anymore, deleting reservation." as message;
		SET SQL_SAFE_UPDATES = 1;

    END IF;
  END IF;
 END IF;
END$$



/*###########################################*/
/*7. Creating View allFlights*/
/*###########################################*/

CREATE VIEW allFlights AS
	(SELECT aiportdept.name AS departure_city_name, 
		   aiportarriv.name AS destination_city_name, 
		   baschedule.departuretime AS departure_time,
           baschedule.day AS departure_day,
           baflight.week AS departure_week,
           baschedule.year AS departure_year,
           stats.seats AS nr_of_free_seats,
		   stats.price AS current_price_per_seat
	FROM baflight
    LEFT JOIN baschedule ON baflight.schedule = baschedule.id
    LEFT JOIN baairport AS aiportarriv ON aiportarriv.id = baschedule.arrivairport
    LEFT JOIN baairport AS aiportdept ON aiportdept.id = baschedule.deptairport
    LEFT JOIN (SELECT id, calculateFreeSeats(id) as seats, calculatePrice(id) as price
    FROM baflight) AS stats ON stats.id = baflight.id);
                        


