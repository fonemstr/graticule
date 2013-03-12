# encoding: UTF-8
module Graticule #:nodoc:
  module Geocoder #:nodoc:

    # First you need a Google Maps API key.  You can register for one here:
    # http://www.google.com/apis/maps/signup.html
    #
    #   gg = Graticule.service(:google).new(MAPS_API_KEY)
    #   location = gg.locate '1600 Amphitheater Pkwy, Mountain View, CA'
    #   p location.coordinates
    #   #=> [37.423111, -122.081783
    #
    class Google < Base
      # http://www.google.com/apis/maps/documentation/#Geocoding_HTTP_Request

      # http://www.google.com/apis/maps/documentation/reference.html#GGeoAddressAccuracy
      PRECISION = {
        0 => Precision::Unknown,      # Unknown location.
        1 => Precision::Country,      # Country level accuracy.
        2 => Precision::Region,       # Region (state, province, prefecture, etc.) level accuracy.
        3 => Precision::Region,       # Sub-region (county, municipality, etc.) level accuracy.
        4 => Precision::Locality,     # Town (city, village) level accuracy.
        5 => Precision::PostalCode,   # Post code (zip code) level accuracy.
        6 => Precision::Street,       # Street level accuracy.
        7 => Precision::Street,       # Intersection level accuracy.
        8 => Precision::Address,      # Address level accuracy.
        9 => Precision::Premise       # Premise (building name, property name, shopping center, etc.) level accuracy.
      }

      def initialize(key)
        @url = URI.parse 'http://maps.googleapis.com/maps/api/geocode/xml'
      end

      # Locates +address+ returning a Location
      def locate(address)
        get :address => address.is_a?(String) ? address : location_from_params(address).to_s
      end

    private
      class Type
        include HappyMapper
        element :name, String, :tag => '.|.//text()'
      end
      
      class AddressComponent
        include HappyMapper
        tag 'address_component'

        attribute :short_name, String
        attribute :long_name, String
        has_many :types, Type
      end

      class GeoLocation
        include HappyMapper
        tag 'location'
        attribute :lat, Float
        attribute :lng, Float
      end

      class Geometry
        include HappyMapper
        tag 'geometry'
        has_one :location, GeoLocation
      end
    
      class GeocodeResponse
        include HappyMapper
        tag 'GeocodeResponse'
        
        element :code, String, :tag => 'status'
        
        has_one :geo_location, Geometry
        has_many :address_components, AddressComponent

        def get_type(type)
          address_components.detect {|component|  component.types.first.name == type } 
        end
      end

      def prepare_response(xml)
        GeocodeResponse.parse(xml, :single => true)
      end

      def parse_response(response) #:nodoc:
        #result = response.placemarks.first
        Location.new(
          :latitude    => response.geo_location.location.lat,
          :longitude   => response.geo_location.location.lng,
          :street      => response.get_type('route').short_name,
          :locality    => response.get_type('locality').short_name,
          :region      => response.get_type('administrative_area_level_1').short_name,
          :postal_code => response.get_type('postal_code').short_name,
          :country     => response.get_type('country').short_name,
          :precision   => :unknown
        )
      end

      # Extracts and raises an error from +xml+, if any.
      def check_error(response) #:nodoc:
        case response.code
        when 'OK' then # ignore, ok
        when 'INVALID_REQUEST' then
          raise AddressError, 'missing address'
        when 'ZERO_RESULTS' then
          raise AddressError, 'unavailable address'
        when 'REQUEST_DENIED' then
          raise CredentialsError, 'request was denied'
        when 'OVER_QUERY_LIMIT' then
          raise CredentialsError, 'too many queries'
        else
          raise Error, "#{response.code}"
        end
      end

      # Creates a URL from the Hash +params+.
      # sets the output type to 'xml'.
      def make_url(params) #:nodoc:
        super params.merge(:sensor => false)
      end
    end
  end
end