ALTER TABLE PRIMERTYPES ADD COLUMN type ENUM('universal', 'custom')

UPDATE PRIMERTYPES SET type='universal' WHERE description LIKE '%insert%'

UPDATE PRIMERTYPES SET type='custom' WHERE description LIKE '%custom%'
