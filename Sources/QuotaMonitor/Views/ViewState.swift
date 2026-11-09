import SwiftUI

// Disambiguates the property wrapper from the newer SDK's State macro.
typealias ViewState<Value> = SwiftUI.State<Value>
