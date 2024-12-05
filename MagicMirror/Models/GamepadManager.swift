import GameController
import MMClientCommon
import OSLog

class GamepadManager {
    var currentPad: MMClientCommon.Gamepad?

    private var leftStick: GCControllerDirectionPad?
    private var rightStick: GCControllerDirectionPad?

    private weak var attachment: MMClientCommon.Attachment?

    init() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCControllerDidBecomeCurrent,
            object: nil, queue: .main
        ) { [weak self] (notification) in
            if let self, let controller = notification.object as? GCController {
                self.setController(controller)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCControllerDidStopBeingCurrent,
            object: nil, queue: .main
        ) { [weak self] (notification) in
            if let self {
                self.setController(nil)
            }
        }
    }

    func enableInputFor(attachment: MMClientCommon.Attachment) {
        self.attachment = attachment
    }

    func disableInput() {
        self.attachment = nil
    }

    private func setController(_ controller: GCController?) {
        guard let controller else {
            self.currentPad = nil
            self.leftStick = nil
            self.rightStick = nil
            return
        }

        Logger.attachment.debug("controller attached: \(String(describing: controller))")

        let id = UInt64(controller.hashValue)
        self.currentPad = Gamepad(id: id, layout: .genericDualStick)
        if let gamepad = controller.extendedGamepad {
            self.leftStick = gamepad.leftThumbstick
            self.rightStick = gamepad.rightThumbstick

            map_axis(gamepad.leftThumbstick.xAxis, to: .leftX, for: id)
            map_axis(gamepad.leftThumbstick.yAxis, to: .leftY, for: id, invert: true)
            map_axis(gamepad.rightThumbstick.xAxis, to: .rightX, for: id)
            map_axis(gamepad.rightThumbstick.yAxis, to: .rightY, for: id, invert: true)

            map_trigger(gamepad.leftTrigger, to: .leftTrigger, for: id)
            map_trigger(gamepad.rightTrigger, to: .rightTrigger, for: id)

            map_button(gamepad.buttonA, to: .south, for: id)
            map_button(gamepad.buttonY, to: .north, for: id)
            map_button(gamepad.buttonB, to: .east, for: id)
            map_button(gamepad.buttonX, to: .west, for: id)

            map_button(gamepad.dpad.left, to: .dpadLeft, for: id)
            map_button(gamepad.dpad.right, to: .dpadRight, for: id)
            map_button(gamepad.dpad.up, to: .dpadUp, for: id)
            map_button(gamepad.dpad.down, to: .dpadDown, for: id)

            map_button(gamepad.leftShoulder, to: .shoulderLeft, for: id)
            map_button(gamepad.rightShoulder, to: .shoulderRight, for: id)

            if let select = gamepad.buttonOptions {
                map_button(select, to: .select, for: id)
            }

            map_button(gamepad.buttonMenu, to: .start, for: id)

            if let logo = gamepad.buttonHome {
                map_button(logo, to: .logo, for: id)
            }

            if let l3 = gamepad.leftThumbstickButton {
                map_button(l3, to: .joystickLeft, for: id)
            }
            if let r3 = gamepad.leftThumbstickButton {
                map_button(r3, to: .joystickRight, for: id)
            }

        } else if let gamepad = controller.microGamepad {
            // Use the directional values based on the orientation of the
            // remote.
            gamepad.allowsRotation = true
        }
    }

    private func map_button(
        _ input: GCControllerButtonInput, to button: GamepadButton,
        for id: UInt64
    ) {
        input.valueChangedHandler = { (_, _, pressed) in
            if let pad = self.currentPad, pad.id == id {
                self.attachment?.gamepadInput(
                    id: id, button: button, state: pressed ? .pressed : .released)
            }
        }
    }

    private func map_axis(
        _ input: GCControllerAxisInput,
        to axis: GamepadAxis,
        for id: UInt64,
        invert: Bool = false
    ) {
        input.valueChangedHandler = { (_, value) in
            if let pad = self.currentPad, pad.id == id {
                let value = invert ? -value : value
                self.attachment?.gamepadMotion(id: id, axis: axis, value: Double(value))
            }
        }
    }

    private func map_trigger(
        _ input: GCControllerButtonInput,
        to axis: GamepadAxis,
        for id: UInt64
    ) {
        input.valueChangedHandler = { (_, value, _) in
            if let pad = self.currentPad, pad.id == id {
                self.attachment?.gamepadMotion(id: id, axis: axis, value: Double(value))
            }
        }
    }
}
