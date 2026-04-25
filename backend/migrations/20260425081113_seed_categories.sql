-- Seed category_types
INSERT INTO category_types (alias, name_ru) VALUES
    ('entertainment', 'Развлечения'),
    ('sport',         'Спорт'),
    ('education',     'Образование'),
    ('food',          'Еда и напитки'),
    ('networking',    'Нетворкинг'),
    ('outdoor',       'На природе');

-- Seed categories
INSERT INTO categories (alias, name_ru, category_type_id) VALUES
    ('party',    'Вечеринка',  (SELECT id FROM category_types WHERE alias = 'entertainment')),
    ('concert',  'Концерт',    (SELECT id FROM category_types WHERE alias = 'entertainment')),
    ('cinema',   'Кино',       (SELECT id FROM category_types WHERE alias = 'entertainment')),
    ('standup',  'Стендап',    (SELECT id FROM category_types WHERE alias = 'entertainment')),
    ('club',     'Клуб',       (SELECT id FROM category_types WHERE alias = 'entertainment')),
    ('football', 'Футбол',     (SELECT id FROM category_types WHERE alias = 'sport')),
    ('running',  'Бег',        (SELECT id FROM category_types WHERE alias = 'sport')),
    ('skating',  'Скейтинг',   (SELECT id FROM category_types WHERE alias = 'sport')),
    ('yoga',     'Йога',       (SELECT id FROM category_types WHERE alias = 'sport')),
    ('cycling',  'Велосипед',  (SELECT id FROM category_types WHERE alias = 'sport')),
    ('lecture',  'Лекция',     (SELECT id FROM category_types WHERE alias = 'education')),
    ('workshop', 'Воркшоп',    (SELECT id FROM category_types WHERE alias = 'education')),
    ('meetup',   'Митап',      (SELECT id FROM category_types WHERE alias = 'education')),
    ('bar',      'Бар',        (SELECT id FROM category_types WHERE alias = 'food')),
    ('dinner',   'Ужин',       (SELECT id FROM category_types WHERE alias = 'food')),
    ('brunch',   'Бранч',      (SELECT id FROM category_types WHERE alias = 'food')),
    ('it',       'IT',         (SELECT id FROM category_types WHERE alias = 'networking')),
    ('business', 'Бизнес',     (SELECT id FROM category_types WHERE alias = 'networking')),
    ('startup',  'Стартап',    (SELECT id FROM category_types WHERE alias = 'networking')),
    ('picnic',   'Пикник',     (SELECT id FROM category_types WHERE alias = 'outdoor')),
    ('hiking',   'Поход',      (SELECT id FROM category_types WHERE alias = 'outdoor')),
    ('camping',  'Кемпинг',    (SELECT id FROM category_types WHERE alias = 'outdoor'));
