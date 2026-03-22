INSERT INTO roles (code, name)
VALUES 
('buyer', 'Покупатель'),
('seller', 'Продавец'),
('admin', 'Администратор')
ON CONFLICT (code) DO NOTHING;

INSERT INTO users (email, password_hash)
SELECT 
  'user' || i || '@mail.com',
  '123456'
FROM generate_series(1, 10) s(i)
ON CONFLICT (email) DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = 'buyer'
ON CONFLICT DO NOTHING;