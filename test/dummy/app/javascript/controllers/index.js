import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

// One prefix: importmap pins already live under controllers/... (FlatPack,
// notifications, push). Extra nested prefixes look for doubled paths and 404.
lazyLoadControllersFrom("controllers", application)
