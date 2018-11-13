class AddGetdateFunction < ActiveRecord::Migration[4.2]
  def up
    execute(%{
            CREATE OR REPLACE FUNCTION getdate() RETURNS timestamptz
                   STABLE LANGUAGE sql AS 'SELECT now()';
    })
  end

  def down
    execute(%{
            DROP FUNCTION IF EXISTS getdate();
    })
  end
end
