-- Таблица арен, где проходят события
-- Содержит информацию об аренах, включая название, город и вместимость
CREATE TABLE Arena (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,  -- Название арены
    city VARCHAR(100) NOT NULL,  -- Город, где находится арена
    capacity INT CHECK (capacity > 0)  -- Вместимость арены
);

-- Таблица событий, которые проходят на аренах
-- Хранит информацию о проведенных зрелищах, включая арену, дату и тип события
CREATE TABLE Event (
    id SERIAL PRIMARY KEY,
    arena_id INT REFERENCES Arena(id) ON DELETE CASCADE,  -- Ссылка на арену
    event_date DATE NOT NULL,  -- Дата проведения события
    event_type VARCHAR(100) NOT NULL  -- Тип события (бой, гонки и т.д.)
);

-- Таблица участников (люди, принимающие участие в событиях)
-- Включает информацию о бойцах, их количестве, силе, стоимости и других характеристиках
CREATE TABLE Participant (
    id SERIAL PRIMARY KEY,
    event_id INT REFERENCES Event(id) ON DELETE CASCADE,  -- Событие, к которому относится участник
    type VARCHAR(50) NOT NULL CHECK (type IN ('гладиатор', 'ретиарий', 'варвар', 'жертва', 'лучник', 'легионер', 'фаланга', 'пращник', 'возничий', 'арвига', 'владелец колесницы')),  -- Тип участника
    count INT CHECK (count >= 0),  -- Количество участников данного типа
    strength_level VARCHAR(50) CHECK (strength_level IN ('новичок', 'опытный', 'ветеран')),  -- Уровень силы
    cost DECIMAL(10,2) CHECK (cost >= 0),  -- Стоимость бойца
    age INT CHECK (age >= 0),  -- Возраст бойца
    battles_count INT CHECK (battles_count >= 0)  -- Количество боев, в которых участвовал
);

-- Таблица зверей, участвующих в зрелищах
-- Описывает животных, их характеристики и зрелищность
CREATE TABLE Beast (
    id SERIAL PRIMARY KEY,
    event_id INT REFERENCES Event(id) ON DELETE CASCADE,  -- Событие, в котором участвует зверь
    species VARCHAR(50) NOT NULL CHECK (species IN ('лев', 'леопард', 'шакал', 'бабуин')),  -- Вид зверя
    count INT CHECK (count >= 0),  -- Количество зверей данного вида
    strength INT CHECK (strength >= 0),  -- Сила зверя
    speed INT CHECK (speed >= 0),  -- Скорость зверя
    entertainment_value DECIMAL(5,2) CHECK (entertainment_value >= 0)  -- Зрелищность зверя
);

-- Таблица результатов боев
-- Содержит информацию о выживших после сражений
CREATE TABLE BattleResult (
    id SERIAL PRIMARY KEY,
    event_id INT REFERENCES Event(id) ON DELETE CASCADE,  -- Событие, к которому относится результат
    participant_type VARCHAR(50) NOT NULL,  -- Тип участника
    survived INT CHECK (survived >= 0)  -- Количество выживших
);

-- Заполнение таблицы арен тестовыми данными
INSERT INTO Arena (name, city, capacity) VALUES 
('Римский Колизей', 'Рим', 50000),
('Амфитеатр в Константинополе', 'Константинополь', 30000),
('Арена ди Верона', 'Верона', 25000),
('Амфитеатр в Ниме', 'Ним', 20000);

-- Заполнение таблицы событий
INSERT INTO Event (arena_id, event_date, event_type) VALUES 
(1, '0108-06-12', 'бой с варварами'),
(1, '0108-06-12', 'травля зверей');

-- Заполнение таблицы участников
INSERT INTO Participant (event_id, type, count, strength_level, cost, age, battles_count) VALUES 
(1, 'гладиатор', 4, 'опытный', 500.00, 25, 10),
(1, 'ретиарий', 2, 'опытный', 600.00, 27, 12),
(1, 'варвар', 8, 'новичок', 200.00, 23, 5),
(2, 'жертва', 4, 'новичок', 50.00, 20, 0);

-- Заполнение таблицы зверей
INSERT INTO Beast (event_id, species, count, strength, speed, entertainment_value) VALUES 
(2, 'лев', 1, 90, 80, 95.00),
(2, 'леопард', 1, 70, 100, 90.00);

-- Заполнение таблицы результатов боев
INSERT INTO BattleResult (event_id, participant_type, survived) VALUES 
(1, 'гладиатор', 2),
(1, 'ретиарий', 1),
(1, 'варвар', 0),
(2, 'жертва', 0),
(2, 'лев', 1),
(2, 'леопард', 1);

-- Представления (VIEW) для удобства просмотра данных
-- Список всех событий с аренами
CREATE VIEW EventDetails AS
SELECT e.id AS event_id, e.event_date, e.event_type, a.name AS arena_name, a.city
FROM Event e
JOIN Arena a ON e.arena_id = a.id;

-- Общее количество участников по событиям
CREATE VIEW ParticipantsSummary AS
SELECT event_id, type, SUM(count) AS total_count
FROM Participant
GROUP BY event_id, type;

-- Общее количество зверей по событиям
CREATE VIEW BeastSummary AS
SELECT event_id, species, SUM(count) AS total_count
FROM Beast
GROUP BY event_id, species;

-- Хранимые процедуры (FUNCTIONS) для работы с данными
-- Добавление или обновление участников события
CREATE OR REPLACE FUNCTION AddOrUpdateParticipant(eventId INT, type VARCHAR, count INT, strength_level VARCHAR, cost DECIMAL, age INT, battles_count INT) RETURNS VOID AS $$
BEGIN
    INSERT INTO Participant (event_id, type, count, strength_level, cost, age, battles_count)
    VALUES (eventId, type, count, strength_level, cost, age, battles_count)
    ON CONFLICT (event_id, type) DO UPDATE
    SET count = EXCLUDED.count, strength_level = EXCLUDED.strength_level, cost = EXCLUDED.cost, age = EXCLUDED.age, battles_count = EXCLUDED.battles_count;
END;
$$ LANGUAGE plpgsql;

-- Удаление события
CREATE OR REPLACE FUNCTION DeleteEvent(eventId INT) RETURNS VOID AS $$
BEGIN
    DELETE FROM Event WHERE id = eventId;
END;
$$ LANGUAGE plpgsql;

-- Триггеры (TRIGGERS) для обеспечения целостности данных
-- Проверка корректности количества выживших бойцов
CREATE OR REPLACE FUNCTION CheckSurvivorCount() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.survived > (SELECT count FROM Participant WHERE event_id = NEW.event_id AND type = NEW.participant_type) THEN
        RAISE EXCEPTION 'Количество выживших не может превышать количество участников';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ValidateSurvivorCount
BEFORE INSERT OR UPDATE ON BattleResult
FOR EACH ROW EXECUTE FUNCTION CheckSurvivorCount();

-- Проверка, чтобы количество участников или зверей не могло быть отрицательным
CREATE OR REPLACE FUNCTION PreventNegativeCount() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.count < 0 THEN
        RAISE EXCEPTION 'Количество участников или зверей не может быть отрицательным';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER PreventNegativeParticipants
BEFORE INSERT OR UPDATE ON Participant
FOR EACH ROW EXECUTE FUNCTION PreventNegativeCount();

CREATE TRIGGER PreventNegativeBeasts
BEFORE INSERT OR UPDATE ON Beast
FOR EACH ROW EXECUTE FUNCTION PreventNegativeCount();
