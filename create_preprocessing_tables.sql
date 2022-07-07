SET foreign_key_checks = 0;

DROP TABLE job, warc;

CREATE TABLE job (
	id SMALLINT NOT NULL AUTO_INCREMENT,
	job_name VARCHAR(30) NOT NULL,
	folder_name VARCHAR(30) NOT NULL,
	start_crawl DATETIME DEFAULT NULL,
	finish_crawl DATETIME DEFAULT NULL,
	status_crawl ENUM('running', 'finished') DEFAULT NULL,
	status_prepro ENUM('running', 'finished') DEFAULT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE warc(
	id INT NOT NULL AUTO_INCREMENT,
	job_id SMALLINT NOT NULL,
	file VARCHAR(50) NOT NULL,
	last_changed DATETIME,
	server VARCHAR(16) NOT NULL,
	copy_in ENUM('running', 'finished', 'error') DEFAULT NULL,
	warcEx ENUM('running', 'finished', 'error') DEFAULT NULL,
	langSepa ENUM('running', 'finished', 'error') DEFAULT NULL,
	outSelect ENUM('running', 'finished', 'error') DEFAULT NULL,
	copy_out ENUM('running', 'finished', 'error') DEFAULT NULL,
	PRIMARY KEY (id),
	FOREIGN KEY (job_id)
     REFERENCES job (id)
     ON UPDATE CASCADE ON DELETE CASCADE 
);

SET foreign_key_checks = 1;

