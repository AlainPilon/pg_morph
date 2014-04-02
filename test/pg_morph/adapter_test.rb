require_relative '../test_helper'

class PgMorph::AdapterTest < PgMorph::UnitTest
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    include PgMorph::Adapter
  end

  class FakeAdapter
    include PgMorph::Adapter

    def execute(sql, name = nil)
      sql_statements << sql
      sql
    end

    def sql_statements
      @sql_statements || []
    end
  end

  setup do
    @adapter = FakeAdapter.new
    @connection = ActiveRecord::Base.connection
  end


  test 'add_polymorphic_foreign_key'
  test 'remove_polymorphic_foreign_key'

  test 'create_child_table_sql' do
    assert_equal(%Q{
      CREATE TABLE master_table_child_table (
        CHECK (column_type = 'ChildTable'),
        PRIMARY KEY (id),
          FOREIGN KEY (column_id) REFERENCES child_table(id)
      ) INHERITS (master_table);
      }.squeeze(' '),
      @adapter.create_child_table_sql(:master_table, :child_table, :column).squeeze(' ')
    )
  end

  test 'create_trigger_fun_sql' do
    @adapter.expects(:before_insert_trigger_content)

    @adapter.create_trigger_fun_sql(:master_table, :to_table, :column)
  end

  test 'create_trigger_body for new trigger' do
    assert_equal(%Q{
      IF (NEW.column_type = 'ChildTable') THEN
        INSERT INTO master_table_child_table VALUES (NEW.*);
      }.squeeze(' '),
      @adapter.create_trigger_body(:master_table, :child_table, :column).squeeze(' ')
    )
  end

  test 'create_trigger_body for existing trigger' do
    @adapter.stubs(:raise_unless_postgres)
    @connection.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    assert_equal(%Q{},
      @adapter.create_trigger_body(:likes, :posts, :likeable))

    @connection.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)
  end

  test 'create_before_insert_trigger_sql' do
    assert_equal(%Q{
      DROP TRIGGER IF EXISTS master_table_column_insert_trigger ON master_table;
      CREATE TRIGGER master_table_column_insert_trigger
        BEFORE INSERT ON master_table
        FOR EACH ROW EXECUTE PROCEDURE master_table_column_fun();
      },
      @adapter.create_before_insert_trigger_sql(:master_table, :to_table, :column)
    )
  end

  test 'remove_partition_table'

  test 'remove_before_insert_trigger_sql if no function' do
    lambda { @adapter.remove_before_insert_trigger_sql(:master_table, :child_table, :column) }
      .must_raise PG::Error
  end

  test 'remove_before_insert_trigger_sql for single child table' do
    @adapter.stubs(:get_function).with('master_table_column_fun').returns('')

    assert_equal(%Q{
      DROP TRIGGER master_table_column_insert_trigger ON master_table;
      DROP FUNCTION master_table_column_fun();
      }.squeeze(' '),
      @adapter.remove_before_insert_trigger_sql(:master_table, :child_table, :column).squeeze(' ')
    )
  end

  test 'remove_before_insert_trigger_sql for multiple child tables' do
    @adapter.stubs(:get_function).with('master_table_column_fun')
      .returns(%Q{})

    assert_equal(%Q{
      DROP TRIGGER master_table_column_insert_trigger ON master_table;
      DROP FUNCTION master_table_column_fun();
      }.squeeze(' '),
      @adapter.remove_before_insert_trigger_sql(:master_table, :child_table, :column).squeeze(' ')
    )

  end

  test 'before_insert_trigger_content' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION function_name() RETURNS TRIGGER AS $$
        BEGIN
          my block
          ELSE
            RAISE EXCEPTION 'Wrong \"column_type\"=\"%\" used. Create propper partition table and update function_name function', NEW.content_type;
          END IF;
        RETURN NULL;
        END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @adapter.before_insert_trigger_content(:function_name, :column) { 'my block' }.squeeze(' ')
    )
  end

end
