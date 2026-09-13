/// Non-web branch: outside a browser there is no one to ask about the input,
/// and nothing to ask for — the platform itself already says what is needed.
///
/// Not a claim about the hardware: a touch screen on a native desktop, and
/// the touch screen of a phone, both answer `false` here. The signal exists
/// to correct what a browser reports about itself, and a native build has
/// nothing to correct.
bool get isTouchInput => false;
