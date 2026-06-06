-- Create buses table
CREATE TABLE IF NOT EXISTS buses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
);

-- Create stops table
CREATE TABLE IF NOT EXISTS stops (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bus_id INTEGER,
    stop_name TEXT,
    latitude REAL,
    longitude REAL,
    stop_order INTEGER,
    FOREIGN KEY(bus_id) REFERENCES buses(id)
);

-- Create live_locations table
CREATE TABLE IF NOT EXISTS live_locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bus_id INTEGER UNIQUE,
    latitude REAL,
    longitude REAL,
    speed REAL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(bus_id) REFERENCES buses(id)
);

-- Seed Bus A
INSERT OR IGNORE INTO buses (id, name) VALUES (1, 'Bus A');

-- Seed stops for Bus A
-- Route: Kottayam -> Kumaranalloor -> Sankranthi -> Ettumanoor -> Peroor -> Kidangoor -> Pala
DELETE FROM stops WHERE bus_id = 1;
INSERT INTO stops (bus_id, stop_name, latitude, longitude, stop_order) VALUES
(1, 'Kottayam', 9.5869, 76.5213, 1),
(1, 'Kumaranalloor', 9.6185, 76.5310, 2),
(1, 'Sankranthi', 9.6250, 76.5383, 3),
(1, 'Ettumanoor', 9.6704, 76.5609, 4),
(1, 'Peroor', 9.6503, 76.5639, 5),
(1, 'Kidangoor', 9.6667, 76.6000, 6),
(1, 'Pala', 9.7138, 76.6829, 7);
