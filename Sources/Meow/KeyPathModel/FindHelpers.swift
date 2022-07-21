import MongoKitten

extension MappedCursor where Base == FindQueryBuilder, Element: KeyPathQueryableModel {
    /// Allows sorting a result stream based on a comparable value within this model `Element`
    public func sort<T: Comparable>(
        on keyPath: KeyPath<Element, QueryableField<T>>,
        direction: Sorting.Order
    ) -> Self {
        let path = Element.resolveFieldPath(keyPath).joined(separator: ".")
        
        return self.sort([
            path: direction
        ])
    }
}
