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
    assert_defaults("B24", width_in: 24, height_in: 34.5, depth_in: 24, toe_height_in: 4.5)
    assert_defaults("W3018", width_in: 18, height_in: 30, depth_in: 12, toe_height_in: 0)
    assert_defaults("P2484", width_in: 24, height_in: 84, depth_in: 24, toe_height_in: 4.5)
  end

  private

  def assert_defaults(code, expected)
    actual = SkilledServices::Catalog::Loader.placement_params(code)
    expected.each { |key, value| assert_equal value, actual[key], "#{code} #{key}" }
  end
end
