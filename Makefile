# (C) Copyright Digital Catapult Limited 2016
.DEFAULT_GOAL := bundle_install

BUNDLE_CMD      = bundle
BUNDLE_PATH     = .bundle
COOKBOOKS_PATH  = cookbooks

.PHONY: bundle_install
bundle_install:
	$(BUNDLE_CMD) install --path $(BUNDLE_PATH)