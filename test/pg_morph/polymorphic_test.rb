require_relative '../test_helper'

class PgMorph::PolymorphicTest < PgMorph::UnitTest
  setup do
    @polymorphic = PgMorph::Polymorphic.new(:foos, :bars, column: :baz)
  end

  test '#column_name' do
    assert_equal :baz, @polymorphic.column_name
  end

  test '#parent_table' do
    assert_equal :foos, @polymorphic.parent_table
  end

  test '#child_table' do
    assert_equal :bars, @polymorphic.child_table
  end

  test '#create_proxy_table_sql' do
    assert_equal(%Q{
      CREATE TABLE foos_bars (
        CHECK (baz_type = 'Bar'),
        PRIMARY KEY (id),
          FOREIGN KEY (baz_id) REFERENCES bars(id)
      ) INHERITS (foos);
      }.squeeze(' '),
      @polymorphic.create_proxy_table_sql.squeeze(' ')
    )
  end

  test 'create_before_insert_trigger_fun_sql' do
    @polymorphic.expects(:before_insert_trigger_content)

    @polymorphic.create_before_insert_trigger_fun_sql
  end

  test 'create_trigger_body for new trigger' do
    assert_equal(%Q{
      IF (NEW.baz_type = 'Bar') THEN
        INSERT INTO foos_bars VALUES (NEW.*);
      }.squeeze(' '),
      @polymorphic.send(:create_trigger_body).squeeze(' ')
    )
  end

  test 'before_insert_trigger_content' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION foos_baz_fun() RETURNS TRIGGER AS $$
        BEGIN
          my block
          ELSE
            RAISE EXCEPTION 'Wrong \"baz_type\"=\"%\" used. Create proper partition table and update foos_baz_fun function', NEW.baz_type;
          END IF;
        RETURN NEW;
        END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @polymorphic.send(:before_insert_trigger_content) { 'my block' }.squeeze(' ')
    )
  end

  test 'create_after_insert_trigger_fun_sql' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION delete_from_foos_master_fun() RETURNS TRIGGER AS $$
      BEGIN
        DELETE FROM ONLY foos WHERE id = NEW.id;
        RETURN NEW;
      END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @polymorphic.create_after_insert_trigger_fun_sql.squeeze(' ')
    )
  end

  test 'create_after_insert_trigger_sql' do
    assert_equal(%Q{
      DROP TRIGGER IF EXISTS foos_after_insert_trigger ON foos;
      CREATE TRIGGER foos_after_insert_trigger
        AFTER INSERT ON foos
        FOR EACH ROW EXECUTE PROCEDURE delete_from_foos_master_fun();
      }.squeeze(' '),
      @polymorphic.create_after_insert_trigger_sql.squeeze(' ')
    )
  end

  test 'remove_before_insert_trigger_sql if no function' do
    lambda { @polymorphic.remove_before_insert_trigger_sql }
      .must_raise PG::Error
  end

  test 'remove_before_insert_trigger_sql for single child table' do
    @polymorphic.stubs(:get_function).with('foos_baz_fun').returns('')

    assert_equal(%Q{
      DROP TRIGGER foos_baz_insert_trigger ON foos;
      DROP FUNCTION foos_baz_fun();
      }.squeeze(' '),
      @polymorphic.remove_before_insert_trigger_sql.squeeze(' ')
    )
  end
end
