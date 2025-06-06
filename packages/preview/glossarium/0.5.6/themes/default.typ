// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// glossarium figure kind
#let __glossarium_figure = "glossarium_entry"

// prefix of label for references query
#let __glossary_label_prefix = "__gls:"

// global state containing the glossary entry and their location
// A glossary entry is a `dictionary`.
// See `__normalize_entry_list`.
#let __glossary_entries = state("__glossary_entries", (:))

// global state containing the entry counts
#let __glossary_counts = state("__glossary_counts", (:))
#let __update_count(key) = {
  __glossary_counts.update(x => {
    x.insert(key, x.at(key, default: 0) + 1)
    return x
  })
}

// glossarium version
#let glossarium_version = "0.5.6"

// error prefix
#let __glossarium_error_prefix = (
  "glossarium@" + glossarium_version + " error : "
)

// Errors types
#let __key_not_found = "key_not_found"
#let __attribute_is_empty = "attribute_is_empty"
#let __glossary_is_empty = "glossary_is_empty"
#let __entry_has_neither_short_nor_long = "entry_has_neither_short_nor_long"
#let __make_glossary_not_called = "make_glossary_not_called"
#let __capitalize_called_with_content_type = "capitalize_called_with_content_type"
#let __entry_has_unknown_keys = "entry_has_unknown_keys"
#let __entry_list_is_not_array = "entry_list_is_not_array"
#let __longplural_but_not_long = "longplural_but_not_long"
#let __unknown_error = "unknown_error"

// __error_message(key, kind, ..kwargs) -> str
// Generate an error message
//
// # Arguments
//  key (str): the key of the term
//  kind (str): the kind of the error
//  kwargs (arguments): additional arguments
//
// # Returns
// The error message
#let __error_message(key, kind, ..kwargs) = {
  let msg = none
  let kwargs = kwargs.named() // convert arguments sink to dictionary

  // Generate the error message
  if kind == __key_not_found {
    msg = "key '" + key + "' not found"
  } else if kind == __attribute_is_empty {
    let attr = kwargs.at("attr")
    msg = "requested attribute " + attr + " is empty for key '" + key + "'"
  } else if kind == __glossary_is_empty {
    msg = "glossary is empty. Use `register-glossary(entry-list)` immediately after `make-glossary`."
  } else if kind == __entry_has_neither_short_nor_long {
    msg = "entry '" + key + "' has neither short nor long form"
  } else if kind == __make_glossary_not_called {
    msg = "make-glossary not called. Add `#show: make-glossary` at the beginning of the document."
  } else if kind == __capitalize_called_with_content_type {
    msg = (
      "Capitalization was requested for " + key + ", but short or long is of type content. Use a string instead."
    )
  } else if kind == __entry_has_unknown_keys {
    let keys = kwargs.at("keys")
    msg = "entry '" + key + "' has unknown keys: " + keys
  } else if kind == __entry_list_is_not_array {
    msg = "entry-list is not an array."
  } else if kind == __longplural_but_not_long {
    msg = key + " has a longplural attribute but no long attribute. Longplural will not be shown."
  } else {
    msg = "unknown error"
  }

  // return the error message
  return __glossarium_error_prefix + msg
}

#let __capitalize(text) = {
  if text == none { return text }
  if type(text) == content {
    panic(__error_message(text, __capitalize_called_with_content_type))
  }
  return upper(text.first()) + text.slice(1)
}
#let __uncapitalize(text) = {
  return lower(text.first()) + text.slice(1)
}

// __query_labels_with_key(loc, key) -> array<label>
// Query the labels with the key
//
// # Arguments
//  loc (location): the location of the reference
//  key (str): the key of the term
//
// # Returns
// The labels with the key
#let __query_labels_with_key(key) = {
  return query(selector(label(__glossary_label_prefix + key)))
}

// __get_entry_with_key(loc, key) -> dictionary
// Get an entry from the glossary
//
// # Arguments
//  loc (location): the location of the reference
//  key (str): the key of the term
//
// # Returns
// The entry of the term
//
// # Panics
// If the key is not found, it will raise a `key_not_found` error
#let __get_entry_with_key(loc, key) = {
  let entries = if sys.version <= version(0, 11, 1) {
    __glossary_entries.final()
  } else {
    __glossary_entries.at(loc)
  }
  let lowerkey = __uncapitalize(key)
  if key in entries {
    return entries.at(key)
  } else if lowerkey in entries {
    return entries.at(lowerkey)
  } else {
    panic(__error_message(key, __key_not_found))
  }
}

// count-refs(key) -> int
// Count the number of references to the entry in the document
//
// # Arguments
// entry (dictionary): the entry
//
// # Returns
// The number of references to the entry
//
// # Usage
// ```typ
// #context count-refs("potato")
// ```
#let count-refs(key) = {
  return __glossary_counts.final().at(key, default: 0)
}

// count-all-refs(entry-list: none, groups: none) -> array<(str, int)>
// Return the number of references for each entry in the document

// # Arguments
// entry-list (array<dictionary>): the list of entries. Defaults to all entries
// groups (array<str>): the list of groups to be considered. `""` is the default group.
//
// # Returns
// The number of references for each entry across the document
//
// # Usage
// ```typ
// #context count-all-refs()
// ```
#let count-all-refs(entry-list: none, groups: none) = {
  let el = if entry-list == none {
    __glossary_entries.get().values()
  } else {
    entry-list
  }
  let g = if groups == none {
    el.map(x => x.at("group", default: "")).dedup()
  } else if type(groups) == array {
    groups
  } else {
    panic("groups must be an array of strings, e.g., (\"\",)")
  }
  el = el.filter(x => x.at("group", default: "") in g)
  let counts = el.map(x => (x.key, count-refs(x.key)))
  return counts
}

// there-are-refs(entry-list: none, groups: none) -> bool
// Check if there are references to the entries in the document
//
// # Arguments
// entry-list (array<dictionary>): the list of entries. Defaults to all entries
// groups (array<str>): the list of groups to be considered. `""` is the default group.
//
// # Returns
// True if there are references to the entries in the document
//
// # Usage
// ```typ
// #context if there-are-refs() {
//   [= Glossary]
// }
// ```
#let there-are-refs(entry-list: none, groups: none) = {
  let counts = count-all-refs(entry-list: entry-list, groups: groups)
  return counts.to-dict().values().any(x => x > 0)
}


// is-first-or-long(ey, long: false) -> bool
// Check if the key is the first reference to the term or long form is requested
//
// # Arguments
//  loc (location): the location of the reference
//  key (str): the key of the term
//  long (bool): if true, it will return true if the long form is requested
//
// # Returns
// True if the key is the first reference to the term or long form is requested
#let is-first-or-long(key, long: false) = {
  return __glossary_counts.get().at(key, default: 0) == 0 or long == true
}

// __link_and_label(key, text, prefix: none, suffix: none, update: true) -> content
// Build a link and a label
//
// # Arguments
//  key (str): the key of the term
//  text (content): the text to be displayed
//  prefix (str|content): the prefix to be added to the label
//  suffix (str|content): the suffix to be added to the label
//
// # Returns
// The link and the entry label
#let __link_and_label(key, text, prefix: none, suffix: none, href: true, update: true) = {
  return [#if update { __update_count(key) }#prefix#if href { link(label(key), text) } else { text }#suffix#label(
      __glossary_label_prefix + key,
    )]
}

#let __get_attribute(entry, attrname) = entry.at(attrname)
#let __get_key(entry) = __get_attribute(entry, "key")
#let __get_short(entry) = __get_attribute(entry, "short")
#let __get_long(entry) = __get_attribute(entry, "long")

#let __get_artshort(entry) = __get_attribute(entry, "artshort")
#let __get_artlong(entry) = __get_attribute(entry, "artlong")
#let __get_plural(entry) = __get_attribute(entry, "plural")
#let __get_longplural(entry) = __get_attribute(entry, "longplural")
#let __get_description(entry) = __get_attribute(entry, "description")
#let __get_group(entry) = __get_attribute(entry, "group")
#let __get_sort(entry) = __get_attribute(entry, "sort")

#let __has_attribute(entry, attrname) = {
  let attr = __get_attribute(entry, attrname)
  return attr != none and attr != "" and attr != []
}
#let has-short(entry) = __has_attribute(entry, "short")
#let has-long(entry) = __has_attribute(entry, "long")
#let has-artshort(entry) = __has_attribute(entry, "artshort")
#let has-artlong(entry) = __has_attribute(entry, "artlong")
#let has-plural(entry) = __has_attribute(entry, "plural")
#let has-longplural(entry) = __has_attribute(entry, "longplural")
#let has-description(entry) = __has_attribute(entry, "description")
#let has-group(entry) = __has_attribute(entry, "group")
#let has-sort(entry) = __has_attribute(entry, "sort")

// get-attribute(key, attr) -> contextual content
// Get the specified attribute from entry
//
// # Arguments
// key (str): the key of the term
// attr (str): the attribute to be retrieved
//
// # Returns
// The attribute of the term
#let get-attribute(key, attrname, link: false, update: false) = context {
  let entry = __get_entry_with_key(here(), key)
  let attr = entry.at(attrname)
  if link {
    return __link_and_label(entry.key, entry.at(attrname), update: update)
  } else if attrname in entry and entry.at(attrname) != none {
    return attr
  } else {
    panic(__error_message(key, __attribute_is_empty, attr: attrname))
  }
}


// gls-key(key, link: false) -> contextual content
// Get the key of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The key of the term
#let gls-key(key, link: false) = get-attribute(key, "key", link: link)

// gls-short(key, link: false) -> contextual content
// Get the short form of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The short form of the term
#let gls-short(key, link: false) = get-attribute(key, "short", link: link)

// gls-artshort(key, link: false) -> contextual content
// Get the article of the short form
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The article of the short form
#let gls-artshort(key, link: false) = get-attribute(
  key,
  "artshort",
  link: link,
)

// gls-plural(key, link: false) -> contextual content
// Get the plural form of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The plural form of the term
#let gls-plural(key, link: false) = get-attribute(key, "plural", link: link)

// gls-long(key, link: false) -> contextual content
// Get the long form of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The long form of the term
#let gls-long(key, link: false) = get-attribute(key, "long", link: link)

// gls-artlong(key, link: false) -> contextual content
// Get the article of the long form
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The article of the long form
#let gls-artlong(key, link: false) = get-attribute(key, "artlong", link: link)

// gls-longplural(key, link: false) -> contextual content
// Get the long plural form of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The long plural form of the term
#let gls-longplural(key, link: false) = get-attribute(
  key,
  "longplural",
  link: link,
)

// gls-description(key, link: false) -> contextual content
// Get the description of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The description of the term
#let gls-description(key, link: false) = get-attribute(
  key,
  "description",
  link: link,
)

// gls-group(key, link: false) -> contextual content
// Get the group of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The group of the term
#let gls-group(key, link: false) = get-attribute(key, "group", link: link)

//
// gls-sort(key, link: false) -> contextual content
// Get the sort of the term
//
// # Arguments
//  key (str): the key of the term
//  link (bool): enable link to glossary
//
// # Returns
// The sort attribute of the term
#let gls-sort(key, link: false) = get-attribute(key, "sort", link: link)

// Check capitalization of user input (@ref, or @Ref) against real key
#let is-upper(key) = key.at(0) != __get_key(__get_entry_with_key(here(), key)).at(0)

// gls(key, suffix: none, long: false, display: none) -> contextual content
// Reference to term
//
// # Arguments
//  key (str): the key of the term
//  suffix (str): the suffix to be added to the short form
//  long (bool): enable/disable the long form
//  display (str): override text to be displayed
//  capitalize (bool): Capitalize first letter of long form
//
// # Returns
// The link and the entry label
#let gls(key, suffix: none, long: false, display: none, link: true, update: true, capitalize: false) = context {
  let entry = __get_entry_with_key(here(), key)

  // Attributes
  let ent-long = __get_long(entry)
  let ent-short = __get_short(entry)
  if capitalize {
    ent-short = __capitalize(ent-short)
    ent-long = __capitalize(ent-long)
  }

  // Conditions
  let is-first-or-long = is-first-or-long(key, long: long)
  let has-long = has-long(entry)
  let has-short = has-short(entry)

  // Link text
  // 1. If `display` attribute is provided, use it
  // 2. Else, if
  //  a. The entry is referenced for the first time OR long form is explicitly requested
  //      AND
  //  b. The entry has a nonempty `long` attribute
  //      AND
  //  c. long form is not disabled
  // 3. Else, return the `short` attribute + suffix
  // Priority order:
  //  1. `gls(key, display: "text")` will return `text`
  //  2. `gls(key, long: false)` will return `short+suffix`
  //  3. If attribute `long` is empty, `gls(key)` will return `short+suffix`
  //  4. The first `gls(key)` will return `long (short+suffix)`
  //  5. `gls(key, long: true)` will return `long (short+suffix)`
  let text = []
  if display != none {
    text += [#display]
  } else if is-first-or-long and has-long or long == true {
    if has-short {
      text += [#ent-long (#ent-short#suffix)]
    } else {
      text += [#ent-long]
    }
  } else {
    text += [#ent-short#suffix]
  }

  return __link_and_label(entry.key, text, href: link, update: update)
}

// gls(key, suffix: none, long: false, display: none) -> contextual content
// Reference to term, capitalized
#let Gls(key, suffix: none, long: false, display: none, link: true, update: true) = gls(
  key,
  suffix: suffix,
  long: long,
  display: display,
  link: link,
  update: update,
  capitalize: true,
)

// agls(key, suffix: none, long: false) -> contextual content
// Reference to term with article
//
// # Arguments
//  key (str): the key of the term
//  suffix (str|content): the suffix to be added to the short form
//  long (bool): enable/disable the long form
//
// # Returns
// The link and the entry label
#let agls(key, suffix: none, long: false, display: none, link: true, update: true, capitalize: false) = context {
  let entry = __get_entry_with_key(here(), key)
  let artlong = __get_artlong(entry)
  let artshort = __get_artshort(entry)
  let is_first_or_long = is-first-or-long(key, long: long)
  let has-long = has-long(entry)
  if capitalize {
    artlong = __capitalize(artlong)
    artshort = __capitalize(artshort)
  }
  let article = if is_first_or_long and has-long or long == true {
    artlong
  } else {
    artshort
  }
  // Compose with gls
  let text = [#article #gls(
      key,
      suffix: suffix,
      long: long,
      display: display,
      link: false,
      update: false,
    )]
  return __link_and_label(entry.key, text, href: link, update: update)
}
#let Agls(key, suffix: none, long: false, display: none, link: true, update: true) = agls(
  key,
  suffix: suffix,
  long: long,
  display: display,
  link: link,
  update: update,
  capitalize: true,
)

// glspl(key, long: false) -> content
// Reference to term with plural form
//
// # Arguments
//  key (str): the key of the term
//  long (bool): enable/disable the long form
//  capitalize (bool): Capitalize first letter of long form
//
// # Returns
// The link and the entry label
#let glspl(key, long: false, link: true, update: true, capitalize: false) = context {
  let default-plural-suffix = "s"
  let entry = __get_entry_with_key(here(), key)

  // Attributes
  let ent-short = __get_short(entry)
  let ent-plural = __get_plural(entry)
  let ent-long = __get_long(entry)
  let ent-longplural = __get_longplural(entry)

  if capitalize {
    ent-short = __capitalize(ent-short)
    ent-long = __capitalize(ent-long)
    ent-plural = __capitalize(ent-plural)
    ent-longplural = __capitalize(ent-longplural)
  }

  // Conditions
  let is-first-or-long = is-first-or-long(key, long: long)
  let has-short = has-short(entry)
  let has-plural = has-plural(entry)
  let has-long = has-long(entry)
  let has-longplural = has-longplural(entry)

  let longplural = if not has-longplural and has-long {
    // Default longplural
    // if the entry long plural is not provided, then fallback to adding default
    // default-plural-suffix
    [#ent-long#default-plural-suffix]
  } else {
    [#ent-longplural]
  }

  let shortplural = if not has-plural {
    // Default short plural
    // if the entry plural is not provided, then fallback to adding default
    // default-plural-suffix
    [#ent-short#default-plural-suffix]
  } else {
    [#ent-plural]
  }

  // Link text
  let text = if is-first-or-long and has-long or long == true {
    if has-short {
      [#longplural (#shortplural)]
    } else {
      [#longplural]
    }
  } else if has-short {
    // Default to short
    [#shortplural]
  } else {
    [#longplural]
  }

  return __link_and_label(entry.key, text, href: link, update: update)
}

// glspl(key, long: false) -> content
// Reference to term with plural form, capitalized
#let Glspl(key, long: false, link: true, update: true) = glspl(
  key,
  long: long,
  link: link,
  update: update,
  capitalize: true,
)

// Select all figure refs and filter by __glossarium_figure
//
// Transform the ref to the glossary term
#let refrule(r, update: true, long: false, link: true) = {
  if (
    r.element != none and r.element.func() == figure and r.element.kind == __glossarium_figure
  ) {
    let position = r.element.location()
    // call to the general citing function
    let key = str(r.target)
    if key.ends-with(":pl") {
      key = key.slice(0, -3)
      // Plural ref
      return glspl(key, update: update, link: link, long: long, capitalize: is-upper(key))
    } else {
      // Default ref
      return gls(key, update: update, link: link, long: long, capitalize: is-upper(key))
    }
  } else {
    return r
  }
}

// make-glossary(body) -> content
// Show rule for glossary
//
// # Arguments
//  body (content): whole document
//
// # Usage
// Transform everything
// ```typ
// #show: make-glossary
// ```
#let make-glossary(body, link: true, always-long: false) = {
  [#metadata("glossarium:make-glossary")<glossarium:make-glossary>]
  // Set figure body alignement
  show figure.where(kind: __glossarium_figure): it => {
    if sys.version >= version(0, 12, 0) {
      align(start, it.body)
    } else {
      it.body
    }
  }
  show ref: refrule.with(link: link, long: always-long)
  body
}

// __normalize_entry_list(entry-list) -> array<dictionary>
// Add default values to each entry.
//
// # Arguments
//  entry-list (array<dictionary>): the list of entries
//  use-key-as-short (bool): flag to use the key as the short form
//
// # Returns
// The normalized entry list
#let __normalize_entry_list(entry-list, use-key-as-short: true) = {
  let new-list = ()
  for entry in entry-list {
    let unknown_keys = entry
      .keys()
      .filter(x => (
        x
          not in (
            "key",
            "short",
            "artshort",
            "plural",
            "long",
            "artlong",
            "longplural",
            "description",
            "group",
            "sort",
          )
      ))
    if unknown_keys.len() > 0 {
      panic(__error_message(entry.key, __entry_has_unknown_keys, keys: unknown_keys.join(",")))
    }
    let newentry = (
      key: entry.key,
      short: entry.at(
        "short",
        default: if use-key-as-short { entry.key } else { none },
      ),
      artshort: entry.at("artshort", default: "a"),
      plural: entry.at("plural", default: none),
      long: entry.at("long", default: none),
      artlong: entry.at("artlong", default: "a"),
      longplural: entry.at("longplural", default: none),
      description: entry.at("description", default: none),
      group: entry.at("group", default: ""),
      sort: entry.at("sort", default: entry.key),
    )
    if not use-key-as-short and not has-short(newentry) and not has-long(newentry) {
      panic(__error_message(newentry.key, __entry_has_neither_short_nor_long))
    }
    if has-longplural(newentry) and not has-long(newentry) {
      panic(__error_message(newentry.key, __longplural_but_not_long))
    }
    new-list.push(newentry)
  }
  return new-list
}

// get-entry-back-references(entry) -> array<content>
// Get the back references of the entry
//
// # Arguments
// entry (dictionary): the entry
//
// # Returns
// The back references as an array of links
#let get-entry-back-references(entry) = {
  let term-references = __query_labels_with_key(entry.key)
  return term-references
    .map(x => x.location())
    .sorted(key: x => x.page())
    .map(x => {
      let page-numbering = x.page-numbering()
      if page-numbering == none {
        page-numbering = "1"
      }
      return link(x)[#numbering(page-numbering, ..counter(page).at(x))]
    })
}

// default-print-back-references(entry) -> content
// Print the back references of the entry
//
// # Arguments
// entry (dictionary): the entry
//
// # Returns
// Joined back references
#let default-print-back-references(entry) = {
  return get-entry-back-references(entry).join(", ")
}

// default-print-description(entry) -> content
// Print the description of the entry
//
// # Arguments
// entry (dictionary): the entry
//
// # Returns
// The description of the entry
#let default-print-description(entry) = {
  return entry.at("description")
}

// default-print-title(entry) -> content
// Print the title of the entry
//
// # Arguments
// entry (dictionary): the entry
//
// # Returns
// The title of the entry
#let default-print-title(entry) = {
  let caption = []
  let txt = strong.with(delta: 200)

  if has-long(entry) and has-short(entry) {
    caption += txt(emph(entry.short) + [ -- ] + entry.long)
  } else if has-long(entry) {
    caption += txt(entry.long)
  } else {
    caption += txt(emph(entry.short))
  }
  return caption
}

// default-print-gloss(
//  entry,
//  show-all: false,
//  disable-back-references: false,
//  minimum-refs: 1,
//  description-separator: ": ",
//  user-print-title: default-print-title,
//  user-print-description: default-print-description,
//  user-print-back-references: default-print-back-references,
// ) -> content
// Print the entry
//
// # Arguments
//  entry (dictionary): the entry
//  show-all (bool): show all entries
//  disable-back-references (bool): disable back references
//  minimum-refs (int): minimum number of references to show the entry
//  ...
//
// # Returns
//  The gloss content
#let default-print-gloss(
  entry,
  show-all: false,
  disable-back-references: false,
  minimum-refs: 1,
  description-separator: ": ",
  user-print-title: default-print-title,
  user-print-description: default-print-description,
  user-print-back-references: default-print-back-references,
) = {
  set par(
    hanging-indent: 1em,
    first-line-indent: 0em,
  )
  // ? references-in-description layout divergence
  if show-all == true or count-refs(entry.key) >= minimum-refs {
    // Title
    user-print-title(entry)

    // Description
    if has-description(entry) {
      // Title - Description separator
      description-separator
      user-print-description(entry)
    }

    // Back references
    // Separate context window to separate BR's query
    context if disable-back-references != true {
      " "
      user-print-back-references(entry)
    }
  }
}


// default-print-reference(
//  entry,
//  show-all: false,
//  disable-back-references: false,
//  minimum-refs: 1,
//  description-separator: ": ",
//  user-print-gloss: default-print-gloss,
//  user-print-title: default-print-title,
//  user-print-description: default-print-description,
//  user-print-back-references: default-print-back-references,
// ) -> content
// Print the entry
//
// # Arguments
//  entry (dictionary): the entry
//  show-all (bool): show all entries
//  disable-back-references (bool): disable back references
//  minimum-refs (int): minimum number of references to show the entry
//  ..;
//
// # Returns
// A glossarium figure+labels
#let default-print-reference(
  entry,
  show-all: false,
  disable-back-references: false,
  minimum-refs: 1,
  description-separator: ": ",
  user-print-gloss: default-print-gloss,
  user-print-title: default-print-title,
  user-print-description: default-print-description,
  user-print-back-references: default-print-back-references,
) = [
  #figure(
    supplement: "",
    kind: __glossarium_figure,
    numbering: none,
    user-print-gloss(
      entry,
      show-all: show-all,
      disable-back-references: disable-back-references,
      minimum-refs: minimum-refs,
      description-separator: description-separator,
      user-print-title: user-print-title,
      user-print-description: user-print-description,
      user-print-back-references: user-print-back-references,
    ),
  )#label(entry.key)
  // The line below adds a ref shorthand for plural form, e.g., "@term:pl"
  #figure(
    kind: __glossarium_figure,
    supplement: "",
  )[]#label(entry.key + ":pl")
  // Same as above, but for capitalized form, e.g., "@Term"
  // Skip if key is already capitalized
  #if upper(entry.key.at(0)) != entry.key.at(0) {
    [
      #figure(
        kind: __glossarium_figure,
        supplement: "",
      )[]#label(__capitalize(entry.key))
      #figure(
        kind: __glossarium_figure,
        supplement: "",
      )[]#label(__capitalize(entry.key) + ":pl")
    ]
  }
]

// default-group-break() -> content
// Default group break
#let default-group-break() = {
  return []
}

// default-print-glossary(
//  entries,
//  groups,
//  show-all: false,
//  disable-back-references: false,
//  group-heading-level: none,
//  minimum-refs: 1,
//  description-separator: ": ",
//  group-sortkey: g => g,
//  entry-sortkey: e => e.sort,
//  user-print-reference: default-print-reference
//  user-group-break: default-group-break,
//  user-print-gloss: default-print-gloss,
//  user-print-title: default-print-title,
//  user-print-description: default-print-description,
//  user-print-back-references: default-print-back-references,
// ) -> contextual content
// Default glossary print function
//
// # Arguments
//  entries (array<dictionary>): the list of entries
//  groups (array<str>): the list of groups
//  show-all (bool): show all entries
//  disable-back-references (bool): disable back references
//  group-heading-level (int): force the level of the group heading
//  minimum-refs (int): minimum number of references to show the entry
//  ...
//
// # Warnings
// A strong warning is given not to override `user-print-reference` without
// careful consideration of `default-print-reference`'s original implementation.
// The package's behaviour may break in unexpected ways if not handled correctly.
//
// # Returns
// The glossary content
#let default-print-glossary(
  entries,
  groups,
  show-all: false,
  disable-back-references: false,
  group-heading-level: none,
  minimum-refs: 1,
  description-separator: ": ",
  group-sortkey: g => g,
  entry-sortkey: e => e.sort,
  user-print-reference: default-print-reference,
  user-group-break: default-group-break,
  user-print-gloss: default-print-gloss,
  user-print-title: default-print-title,
  user-print-description: default-print-description,
  user-print-back-references: default-print-back-references,
) = {
  if group-heading-level == none {
    let previous-headings = query(selector(heading).before(here()))
    if previous-headings.len() != 0 {
      group-heading-level = previous-headings.last().level + 1
    } else {
      group-heading-level = 1
    }
  }

  for group in groups.sorted(key: group-sortkey) {
    let group-entries = entries.filter(x => x.at("group") == group)
    let group-ref-counts = group-entries.map(x => count-refs(x.key))
    let print-group = (
      // ? group-heading-pagebreak Layout divergence if location is conditional on print-group
      group != "" and (show-all == true or group-ref-counts.any(x => x >= minimum-refs))
    )
    // Only print group name if any entries are referenced
    if print-group {
      heading(group, level: group-heading-level, outlined: false)
    }
    for entry in group-entries.sorted(key: entry-sortkey) {
      user-print-reference(
        entry,
        show-all: show-all,
        disable-back-references: disable-back-references,
        minimum-refs: minimum-refs,
        description-separator: description-separator,
        user-print-gloss: user-print-gloss,
        user-print-title: user-print-title,
        user-print-description: user-print-description,
        user-print-back-references: user-print-back-references,
      )
    }
    user-group-break()
  }
}

//  __update_glossary(entries) -> none
// Update the global state glossary
//
// # Arguments
//  entries (array<dictionary>): the list of entries
#let __update_glossary(entries) = {
  __glossary_entries.update(x => {
    for entry in entries {
      if entry.key in entries {
        panic("Duplicate key: " + entry.key)
      }
      x.insert(entry.key, entry)
    }
    return x
  })
}

// register-glossary(entry-list, use-key-as-short: true) -> none
// Register the glossary entries
//
// # Arguments
//  entries (array<dictionary>): the list of entries
//  use-key-as-short (bool): flag to use the key as the short form
#let register-glossary(entry-list, use-key-as-short: true) = {
  if sys.version <= version(0, 11, 1) {
    return
  }
  if type(entry-list) != array {
    panic(__error_message(none, __entry_list_is_not_array))
  }
  // Normalize entry-list
  let entries = __normalize_entry_list(
    entry-list,
    use-key-as-short: use-key-as-short,
  )

  __update_glossary(entries)
}

// print-glossary(
//  entry-list,
//  groups: (),
//  show-all: false,
//  disable-back-references: false,
//  group-heading-level: none,
//  minimum-refs: 1,
//  description-separator: ": ",
//  group-sortkey: g => g,
//  entry-sortkey: e => e.sort,
//  user-print-glossary: default-print-glossary,
//  user-print-reference: default-print-reference,
//  user-group-break: default-group-break,
//  user-print-gloss: default-print-gloss,
//  user-print-title: default-print-title,
//  user-print-description: default-print-description,
//  user-print-back-references: default-print-back-references,
// ) -> content
// Print the glossary
//
// # Arguments
//  entry-list (array<dictionary>): the list of entries
//  groups (array<str>): the list of groups to be displayed. `""` is the default group.
//  show-all (bool): show all entries
//  disable-back-references (bool): disable back references
//  group-heading-level (int): force the level of the group heading
//  minimum-refs (int): minimum number of references to show the entry
//  ...
//
// # Warnings
// A strong warning is given not to override `user-print-reference` without
// careful consideration of `default-print-reference`'s original implementation.
// The package's behaviour may break in unexpected ways if not handled correctly.
//
// # Usage
// Print the glossary
// ```typ
// print-glossary(entry-list)
// ```
#let print-glossary(
  entry-list,
  groups: (),
  show-all: false,
  disable-back-references: false,
  group-heading-level: none,
  minimum-refs: 1,
  description-separator: ": ",
  group-sortkey: g => g,
  entry-sortkey: e => e.sort,
  user-print-glossary: default-print-glossary,
  user-print-reference: default-print-reference,
  user-group-break: default-group-break,
  user-print-gloss: default-print-gloss,
  user-print-title: default-print-title,
  user-print-description: default-print-description,
  user-print-back-references: default-print-back-references,
) = context {
  {
    if query(<glossarium:make-glossary>).len() == 0 {
      panic(__error_message(none, __make_glossary_not_called))
    }
  }
  if entry-list == none {
    panic("entry-list is required")
  }
  if type(groups) != array {
    panic("groups must be an array")
  }
  let entries = ()
  if sys.version <= version(0, 11, 1) {
    // Normalize entry-list
    entries = __normalize_entry_list(entry-list)

    // Update state
    __update_glossary(entries)
  } else {
    {
      if __glossary_entries.get().len() == 0 {
        panic(__error_message(none, __glossary_is_empty))
      }
    }
  }

  // Glossary
  let body = []
  body += {
    show ref: refrule.with(update: false)

    // Entries
    let el = if sys.version <= version(0, 11, 1) {
      entries
    } else if entry-list != none {
      __glossary_entries
        .get()
        .values()
        .filter(x => (
          x.key in entry-list.map(x => x.key)
        ))
    }

    // Groups
    let g = if groups == () {
      el.map(x => x.at("group")).dedup()
    } else {
      groups
    }
    user-print-glossary(
      el,
      g,
      show-all: show-all,
      disable-back-references: disable-back-references,
      group-heading-level: group-heading-level,
      minimum-refs: minimum-refs,
      description-separator: description-separator,
      group-sortkey: group-sortkey,
      entry-sortkey: entry-sortkey,
      user-print-reference: user-print-reference,
      user-group-break: user-group-break,
      user-print-gloss: user-print-gloss,
      user-print-title: user-print-title,
      user-print-description: user-print-description,
      user-print-back-references: user-print-back-references,
    )
  }

  // Content
  body
}
