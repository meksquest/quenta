defmodule Quenta.Repo.Migrations.InsertUsers do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO users (name, inserted_at, updated_at)
    VALUES
      ('George', NOW(), NOW()),
      ('Meks', NOW(), NOW());
    """
  end

  def down do
    execute """
    TRUNCATE users;
    """
  end
end
