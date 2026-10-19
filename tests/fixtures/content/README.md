# Content compatibility fixtures

`pre_inheritance_item.tres` is the enum-based ItemDefinition Resource saved before
the shared CollectibleDefinition extraction. It preserves the serialization from
workspace/tasks/test-runs/20261019_190418_071077/item_definition/item_definition.tres
as an immutable compatibility fixture. It is not a production item or catalog
entry. The collectible definition regression test verifies the original fields
still load through the same ItemDefinition script after inheritance changes.
