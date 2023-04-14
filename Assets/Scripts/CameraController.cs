using UnityEngine;

public class CameraController : MonoBehaviour
{
    public float moveSpeed = 5;
    public float sensitivity = 100.0f;

    private float _rotationX;
    private float _rotationY;

    private void Awake()
    {
        // lock cursor
        Cursor.lockState = CursorLockMode.Locked;
    }
    
    void Update()
    {
        Move();
        MouseLook();
        UpdateMouseLock();
    }

    private void UpdateMouseLock()
    {
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            Cursor.lockState = Cursor.lockState == CursorLockMode.None ? CursorLockMode.Locked : CursorLockMode.None;
        }
    }

    private void OnApplicationFocus(bool hasFocus)
    {
        Cursor.lockState = CursorLockMode.Locked;
    }

    private void Move()
    {
        if (Input.GetKey(KeyCode.W))
        {
            transform.Translate(Vector3.forward * moveSpeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.S))
        {
            transform.Translate(Vector3.back * moveSpeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.A))
        {
            transform.Translate(Vector3.left * moveSpeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.D))
        {
            transform.Translate(Vector3.right * moveSpeed * Time.deltaTime);
        }
    }

    private void MouseLook()
    {
        // only update if cursor is locked
        if (Cursor.lockState != CursorLockMode.Locked)
            return;
        
        var mouseX = Input.GetAxis("Mouse X") * sensitivity * Time.deltaTime;
        var mouseY = -Input.GetAxis("Mouse Y") * sensitivity * Time.deltaTime;

        _rotationX -= mouseY;
        _rotationX = Mathf.Clamp(_rotationX, -90.0f, 90.0f);

        _rotationY += mouseX;

        transform.localEulerAngles = new Vector3(-_rotationX, _rotationY, 0.0f);
    }
}
