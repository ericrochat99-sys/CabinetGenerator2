# frozen_string_literal: true

require "minitest/autorun"
require_relative "../skilled_services/catalog/loader"

class CatalogTest < Minitest::Test
  def test_all_family_files_load_and_codes_are_unique
    items = SkilledServices::Catalog::Loader.all
    assert_operator items.length, :>=, 10
    assert_equal items.length, items.map { |item| item["code"] }.uniq.length
    assert_equal SkilledServices::Catalog::Loader::FILES.sort,
      SkilledServices::Catalog::Loader.categories.map(&:downcase).map { |name| name == "accessories" ? name : name }.uniq.sort
  end

  def test_required_standard_defaults
    assert_defaults("B24", width_in: 24, height_in: 34.5, depth_in: 24, toe_height_in: 4)
    assert_defaults("W3018", width_in: 18, height_in: 30, depth_in: 12, toe_height_in: 0)
    assert_defaults("P2484", width_in: 24, height_in: 84, depth_in: 24, toe_height_in: 4)
  end

  def test_full_item_number_loads_every_dimension_and_family_setting
    actual = SkilledServices::Catalog::Loader.placement_params("W12-48/30/15")
    assert_equal "Wall", actual[:cabinet_type]
    assert_equal 15.0, actual[:width_in]
    assert_equal 48.0, actual[:height_in]
    assert_equal 30.0, actual[:depth_in]
    assert_equal 2, actual[:door_count]
    assert_equal 0, actual[:drawer_count]
  end

  def test_full_item_number_accepts_typographic_dash_and_partition_suffix
    actual = SkilledServices::Catalog::Loader.placement_params("B12P–32/24/42")
    assert_equal "B12P", actual[:catalog_code]
    assert_equal 34.5, actual[:height_in]
    assert_equal 42.0, actual[:width_in]
    assert_equal 1, actual[:partition_count]
  end

  def test_invalid_item_number_is_not_loaded
    assert_nil SkilledServices::Catalog::Loader.placement_params("W12-nope")
  end

  def test_ada_lavatory_catalog_defaults
    actual = SkilledServices::Catalog::Loader.placement_params("ADA30")
    assert_equal "ADA Sink", actual[:cabinet_type]
    assert_equal 36, actual[:width_in]
    assert_equal 34, actual[:height_in]
    assert_equal 24, actual[:depth_in]
    assert_equal 0, actual[:shelf_count]
    refute actual[:show_doors]
  end

  private

  def assert_defaults(code, expected)
    actual = SkilledServices::Catalog::Loader.placement_params(code)
    expected.each { |key, value| assert_equal value, actual[key], "#{code} #{key}" }
  end
end
