require 'test_helper'

class QueryExecutorTest < ActiveSupport::TestCase
  
  def setup   
    Mongoid.master.drop_collection('query_results')
    if defined?(QueryExecutor.test_setup)
      QueryExecutor.test_setup
    end

  end

  def test_execute
    mf = File.read('test/fixtures/map_reduce/simple_map.js')
    rf = File.read('test/fixtures/map_reduce/simple_reduce.js')
    q = Query.create(map: mf, reduce: rf)
    qe = QueryJob::QueryExecutor.new('js', mf, rf, nil,q.id.to_s)

    results =  qe.execute
    assert_equal 213, results['M'].to_i
  end
  
  def test_hqmf_execute
    hqmf_contents = File.open('test/fixtures/NQF59New.xml').read
    map_reduce = HQMF2JS::Converter.generate_map_reduce(hqmf_contents)
    map = map_reduce[:map]
    reduce = map_reduce[:reduce]
    functions = map_reduce[:functions]
    
    query = Query.create(:format => 'hqmf', :map => map, :reduce => reduce, :functions => functions)
    query_executor = QueryJob::QueryExecutor.new('hqmf', map, reduce, functions, query.id.to_s)
    results = query_executor.execute
    
    assert_equal 277, results['ipp'].to_i
    assert_equal 46, results['denom'].to_i
    assert_equal 15, results['numer'].to_i
    assert_equal 31, results['antinum'].to_i
  end
end
