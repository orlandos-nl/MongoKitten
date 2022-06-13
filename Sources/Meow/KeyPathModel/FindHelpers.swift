import MongoKitten

extension MappedCursor where Base == FindQueryBuilder, Element: KeyPathQueryableModel {
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
